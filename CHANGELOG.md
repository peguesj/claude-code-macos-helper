# Changelog

All notable changes to Claude Helper are documented in this file. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] — 2026-05-26

### Added
- **JSONL transcript daemon** (`~/.claude/hooks/compute_usage_live.py`) — reads Claude Code transcript files directly from `~/.claude/projects/**/*.jsonl` to produce authoritative token counts. Byte-offset cache (`usage-live-cache.json`) makes incremental re-scans O(new bytes), not O(all history). Runs every 120 s via `~/Library/LaunchAgents/io.pegues.claudeusage.plist`. Outputs `~/.claude/usage-live.json` — the new primary data source for the menubar app.
- **Sonnet-only token tracking** — daemon parses the `message.model` field from each assistant turn and accumulates a separate Sonnet counter alongside the all-models total.
- **Percentage labels on week meters** — each week meter now shows `<used> / <limit>` plus a colour-coded percentage badge: green < 50 %, yellow 50–79 %, red ≥ 80 %.

### Changed
- **Correct Tue–Mon calendar week window** — week aggregation now uses the most recent Tuesday as the epoch (matching claude.ai's "Resets Mon 11:59 PM" display). Previously used a rolling 7-day window that diverged from actual quota resets.
- **Recalibrated token limits for Max 20x** — empirically derived from live claude.ai readings on 2026-05-26 (9 % at 21.4 M all-models; 10 % at 13.1 M Sonnet): all-models 240 M (was 63 M), Sonnet 130 M (was 33 M). Max 5×, Pro, and Free limits scaled proportionally.
- **`usage-live.json` as primary data source** — `LocalSnapshotReader` now tries the daemon output first; `stats-cache.json` and per-session snapshots remain as ordered fallbacks. Daemon output is rejected if older than 10 minutes.
- **FSEvents watcher extended** — `TelemetryService` now watches `~/.claude/usage-live.json` in addition to `stats-cache.json` and the snapshots directory; meters update within 500 ms of any daemon write.
- **GitHub Pages** — hero lede updated to emphasise local JSONL reading, popover mock reflects `(wk)` labels and percentage display, "How it works" diagram shows daemon pipeline.

## [0.2.0] — 2026-05-21

### Added
- **Live telemetry** — FSEvents `DispatchSource` file watcher on `~/.claude/stats-cache.json` and `usage-snapshots/` directory; meters update within 500 ms of any hook write, no polling required. 60 s timer kept as fallback.
- **AppIcon** — liquid-glass macOS icon: dark charcoal squircle, copper (#cc785c) Claude C-arc with glow filter, frosted-glass radial gradient, specular top-edge highlight, squircle border shimmer.
- **Sparkle EdDSA key** wired into `Info.plist` (`SUPublicEDKey`) so update-check no longer fails.
- **Appcast** (`docs/appcast.xml`) published to GitHub Pages — resolves "Check for Updates failed" (previously 404).

### Changed
- **Max 20x week limits corrected** — empirically derived from observed claude.ai percentages: all-models 63 M (was 252 M), Sonnet 33 M (was 84 M). Max 5× and 20× share the same weekly quota; the plan multiplier scales the per-session rate only.
- **Session/Today meter** — `limit` set to `0` (no progress bar) because today's stats-cache cumulative spans multiple rate-limit windows and would misrepresent current window saturation. Raw token count still displayed.
- **Stats-cache as primary data source** — `LocalSnapshotReader` reads `~/.claude/stats-cache.json` directly instead of relying solely on hook-written snapshots. Eliminates multi-session cross-contamination.
- **Per-session snapshot files** — hook now writes `~/.claude/usage-snapshots/<session_id>.json` to prevent concurrent sessions stomping each other's data.
- **OAuth fallback** corrected — `AnthropicUsageClient` catch block now falls back to `LocalSnapshotReader` instead of returning stub values when Admin API auth fails.

## [0.1.0] — 2026-05-11

### Added
- Menubar status item with Claude icon and three inline usage meters (session, all-models, sonnet-only).
- Tabbed settings popover: Overview, Profiles, Limits, Spend, Settings.
- Multi-profile system with Keychain-backed secret storage and isolated `WKProcessPool` per profile.
- claude.ai session capture and restore via cookie storage — switch active web session without re-login.
- Local CLI config writer that mutates `~/.claude/settings.json` on profile switch.
- Anthropic usage API client with 60s telemetry polling and exponential backoff.
- Deep-link buttons for plan, billing, spend limit, and auto-reload pages on claude.ai.
- Local spend ledger (GRDB/SQLite) with daily aggregates and forecast extrapolation.
- Auto-reload reminders via `UserNotifications` when projected spend exceeds 80% of limit.
- LaunchAtLogin, Sparkle auto-updates, AppleScript scripting bridge.
- v0.1.0 GitHub release with universal `.app` artifact and EdDSA-signed Sparkle appcast.
