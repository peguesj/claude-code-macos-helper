import Foundation

/// Anthropic usage/cost report client.
/// Uses the Admin API endpoints `/v1/organizations/usage_report/messages` and `/v1/organizations/cost_report`.
/// Falls back to a stub snapshot when no key is configured or the org doesn't expose the Admin API.
actor AnthropicUsageClient {
    var apiKey: String?
    var currentPlan: Plan = Plan(kind: .max5x)
    private let session: URLSession

    init(apiKey: String? = nil, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    func setKey(_ key: String?) { self.apiKey = key }
    func setPlan(_ plan: Plan)  { self.currentPlan = plan }

    func fetchSnapshot() async -> TelemetrySnapshot {
        guard let key = apiKey, !key.isEmpty else {
            return LocalSnapshotReader.read(plan: currentPlan) ?? stubSnapshot()
        }

        do {
            async let usage = fetchUsageReport(key: key)
            async let cost  = fetchCostReport(key: key)
            let (u, c) = try await (usage, cost)
            return assemble(usage: u, cost: c)
        } catch {
            Log.warn("Usage fetch failed: \(error.localizedDescription) — falling back to local snapshot")
            return LocalSnapshotReader.read(plan: currentPlan) ?? stubSnapshot()
        }
    }

    private struct UsageBucket: Decodable {
        let model: String?
        let input_tokens: Int?
        let output_tokens: Int?
    }
    private struct UsageReport: Decodable { let data: [UsageBucket] }
    private struct CostReport: Decodable {
        struct Item: Decodable { let amount_usd: Double? }
        let data: [Item]
    }

    private func fetchUsageReport(key: String) async throws -> UsageReport {
        let url = URL(string: "https://api.anthropic.com/v1/organizations/usage_report/messages?starting_at=\(yesterdayISO())")!
        return try await getJSON(url: url, key: key)
    }

    private func fetchCostReport(key: String) async throws -> CostReport {
        let url = URL(string: "https://api.anthropic.com/v1/organizations/cost_report?starting_at=\(yesterdayISO())")!
        return try await getJSON(url: url, key: key)
    }

    private func getJSON<T: Decodable>(url: URL, key: String) async throws -> T {
        var req = URLRequest(url: url)
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "AnthropicUsage", code: -1)
        }
        switch http.statusCode {
        case 200..<300:
            return try JSONDecoder().decode(T.self, from: data)
        case 429, 529:
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            return try await getJSON(url: url, key: key)
        default:
            throw NSError(domain: "AnthropicUsage", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"])
        }
    }

    private func assemble(usage: UsageReport, cost: CostReport) -> TelemetrySnapshot {
        let allTokens = usage.data.reduce(0) { $0 + ($1.input_tokens ?? 0) + ($1.output_tokens ?? 0) }
        let sonnetTokens = usage.data.filter { ($0.model ?? "").lowercased().contains("sonnet") }
            .reduce(0) { $0 + ($1.input_tokens ?? 0) + ($1.output_tokens ?? 0) }
        let sessionTokens = min(allTokens, 200_000)

        return TelemetrySnapshot(
            session:    TelemetryMeter(label: "session",    used: Double(sessionTokens), limit: 200_000, resetsAt: nextHour()),
            allModels:  TelemetryMeter(label: "all-models", used: Double(allTokens),     limit: 5_000_000, resetsAt: nextResetDay()),
            sonnetOnly: TelemetryMeter(label: "sonnet",     used: Double(sonnetTokens),  limit: 2_000_000, resetsAt: nextResetDay()),
            lastUpdated: Date()
        )
    }

    private func stubSnapshot() -> TelemetrySnapshot {
        TelemetrySnapshot(
            session:    TelemetryMeter(label: "session",    used: 42,    limit: 100,        resetsAt: nextHour()),
            allModels:  TelemetryMeter(label: "all-models", used: 1_240_000, limit: 5_000_000, resetsAt: nextResetDay()),
            sonnetOnly: TelemetryMeter(label: "sonnet",     used: 380_000,   limit: 2_000_000, resetsAt: nextResetDay()),
            lastUpdated: Date()
        )
    }

    private func nextHour() -> Date {
        Calendar.current.nextDate(after: Date(), matching: DateComponents(minute: 0), matchingPolicy: .nextTime) ?? Date()
    }
    private func nextResetDay() -> Date {
        Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    }
    private func yesterdayISO() -> String {
        let d = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        return ISO8601DateFormatter().string(from: d)
    }
}
