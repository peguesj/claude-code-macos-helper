# Changelog

All notable changes to Claude Helper are documented in this file. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
