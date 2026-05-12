import SwiftUI

struct ProfilesTab: View {
    @EnvironmentObject var profileStore: ProfileStore
    @State private var showAddSheet = false
    @State private var pendingDelete: Profile?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Profiles").font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary).textCase(.uppercase)
                Spacer()
                Button {
                    showAddSheet = true
                } label: { Label("Add", systemImage: "plus.circle.fill") }
                .buttonStyle(.borderless)
            }

            if profileStore.profiles.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(profileStore.profiles) { profile in
                            ProfileRow(profile: profile,
                                       active: profile.id == profileStore.activeProfile?.id,
                                       onActivate: { try? profileStore.activate(profileID: profile.id) },
                                       onDelete: { pendingDelete = profile })
                        }
                    }
                }
            }
            Spacer()
        }
        .sheet(isPresented: $showAddSheet) { AddProfileSheet() }
        .alert("Delete profile?", isPresented: .init(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { pendingDelete = nil }
            Button("Delete", role: .destructive) {
                if let p = pendingDelete { try? profileStore.delete(profileID: p.id) }
                pendingDelete = nil
            }
        } message: {
            Text("Removes \(pendingDelete?.name ?? "") and its keychain entries.")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(.tertiary)
            Text("No profiles yet").foregroundStyle(.secondary)
            Text("Add a profile to hold an API key, claude.ai session, and CLI config.")
                .font(.caption).foregroundStyle(.tertiary)
                .multilineTextAlignment(.center).frame(maxWidth: 280)
            Button("Add your first profile") { showAddSheet = true }
                .buttonStyle(.borderedProminent).padding(.top, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ProfileRow: View {
    let profile: Profile
    let active: Bool
    let onActivate: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(profile.swiftUIAccent).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(profile.name).font(.system(size: 13, weight: .medium))
                    if active {
                        Text("ACTIVE").font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Color.accentColor.opacity(0.18), in: Capsule())
                            .foregroundStyle(Color.accentColor)
                    }
                }
                Text(profile.plan.displayName).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if !active { Button("Activate", action: onActivate).buttonStyle(.borderless) }
            Menu {
                Button("Re-capture session") { }
                Divider()
                Button("Delete", role: .destructive, action: onDelete)
            } label: { Image(systemName: "ellipsis.circle").imageScale(.medium) }
            .menuStyle(.borderlessButton).frame(width: 28)
        }
        .padding(8)
        .background(active ? Color.accentColor.opacity(0.08) : Color.gray.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct AddProfileSheet: View {
    @EnvironmentObject var profileStore: ProfileStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var apiKey = ""
    @State private var planKind: Plan.Kind = .max5x

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Add profile").font(.headline)
            Form {
                TextField("Name", text: $name).textFieldStyle(.roundedBorder)
                SecureField("Anthropic API key (sk-ant-...)", text: $apiKey).textFieldStyle(.roundedBorder)
                Picker("Plan", selection: $planKind) {
                    ForEach(Plan.Kind.allCases) { kind in
                        Text(Plan(kind: kind).displayName).tag(kind)
                    }
                }
            }
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Save") {
                    let profile = Profile(name: name.isEmpty ? "Untitled" : name, plan: Plan(kind: planKind))
                    try? profileStore.save(profile, apiKey: apiKey)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || apiKey.isEmpty)
            }
        }
        .padding(20).frame(width: 380)
    }
}
