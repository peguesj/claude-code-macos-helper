# Claude Helper — Project Instructions

## Plane Project
Project ID: `add1ba19-c332-4831-a5cb-d093171b19cc`
Workspace: `lgtm`
Prefix: `CMH`

## Current version
0.3.0 (CFBundleVersion 3), HEAD `71c18fc`, tag `v0.3.0`

## Build
```bash
make app CONFIG=debug   # dev build, ad-hoc signed
make app                # release (universal arm64+x86_64)
```
Always rebuild with `make app` then `open dist/ClaudeHelper.app` — never run the binary directly (NSStatusItem requires an .app bundle).

## Key files
- `Sources/ClaudeHelper/Services/TelemetryService.swift` — FSEvents watcher + 60s fallback poll
- `Sources/ClaudeHelper/Services/FileSystemWatcher.swift` — kqueue DispatchSource, debounce 500ms
- `Sources/ClaudeHelper/Services/LocalSnapshotReader.swift` — reads `~/.claude/usage-live.json` (primary)
- `Sources/ClaudeHelper/Services/KeychainHelper.swift` — Keychain access (see known issue below)
- `Sources/ClaudeHelper/Models/Plan.swift` — per-plan token limits (240M/130M for max20x)
- `~/.claude/hooks/compute_usage_live.py` — LaunchAgent daemon; scans JSONL transcripts → usage-live.json
- `~/Library/LaunchAgents/io.pegues.claudeusage.plist` — runs daemon every 120s
- `scripts/generate_icon.py` — regenerate AppIcon PNGs (requires rsvg-convert)
- `docs/appcast.xml` — Sparkle update feed (published to GitHub Pages)

## Known issue: Keychain ACL prompts on dev builds
Ad-hoc signing produces a new code signature each build. Keychain items auto-ACL to the creating signature → subsequent builds prompt. Fix is deferred: add `kSecUseDataProtectionKeychain: true` to all `KeychainHelper` queries + one-time migration. See `.claude/handoff-v0.2.0.md` for full spec. Workaround: click "Always Allow" during development.

## Appcast status
`docs/appcast.xml` exists (GitHub Pages) but `sparkle:edSignature` is `PLACEHOLDER_SIGN_ON_RELEASE`. Must be replaced before auto-update works. See handoff for release steps.

## Implementation checkpoints

### v0.1.0 — Foundation (all Done)
- [x] **CMH-01**: SPM project scaffold, menubar status item, Claude arc icon
- [x] **CMH-02**: Tabbed popover (Overview, Profiles, Limits, Spend, Settings)
- [x] **CMH-03**: Multi-profile system, Keychain-backed secrets
- [x] **CMH-04**: claude.ai session capture/restore via cookie storage
- [x] **CMH-05**: CLI config writer → `~/.claude/settings.json`
- [x] **CMH-06**: Anthropic usage API client, 60s poll, exponential backoff
- [x] **CMH-07**: Deep-link buttons (plan, billing, spend limit, auto-reload)
- [x] **CMH-08**: Spend ledger (GRDB/SQLite), daily aggregates, forecast
- [x] **CMH-09**: Auto-reload reminders (UserNotifications, 80% threshold)
- [x] **CMH-10**: LaunchAtLogin, Sparkle, AppleScript bridge
- [x] **CMH-11**: Forecaster (usage-pace vs dollar projection)
- [x] **CMH-17..CMH-20**: Screenshots, .app bundle fixes
- [x] **CMH-21..CMH-25**: Bootstrap profile, design tokens, GitHub Pages, README

### v0.2.0 — Live telemetry + polish (all Done)
- [x] **CMH-12**: Spend forecast fix (no $360K absurd projection), plan-aware usage-pace
- [x] **CMH-13**: FileSystemWatcher — FSEvents live telemetry (kqueue/DispatchSource)
- [x] **CMH-14**: Max 20x week limits corrected (63M all-models, 33M sonnet)
- [x] **CMH-15**: Session/Today meter limit=0 (raw count, no misleading bar)
- [x] **CMH-16**: Liquid-glass AppIcon — iconutil-built .icns, all 10 sizes
- [x] **CMH-17**: SUPublicEDKey wired into Info.plist
- [x] **CMH-18**: docs/appcast.xml — fix Check for Updates 404
- [x] **CMH-19**: Version bump 0.1.0 → 0.2.0
- [x] **CMH-20**: UsageSnapshot hook bridge, stats-cache primary source, per-session snapshots

### v0.3.0 — Accurate JSONL telemetry (shipped `604b1c6`, tag `v0.3.0`)
- [x] **CMH-21**: JSONL transcript daemon — `compute_usage_live.py` LaunchAgent, byte-offset cache, 100ms incremental
- [x] **CMH-22**: Correct Tue–Mon calendar week window (was rolling 7-day); limits recalibrated 240M/130M for max20x
- [x] **CMH-23**: Percentage labels on week meters (color-matched green/yellow/red)
- [x] **CMH-24**: GitHub Pages v0.3.0 — updated lede, popover mock, "How it works" daemon diagram

### v0.3.0+ — Post-ship telemetry fixes (2026-05-29)
- [x] **CMH-25**: Session meter — current conversation token count from most-recent JSONL file; no limit bar (raw count); daemon outputs `session` field
- [x] **CMH-26**: Recalibrate Max 20x limits to 420M all-models / 230M sonnet (mid-week empirical; previous 240M/130M had high error from day-1 data); meter order Session → Sonnet → All models

### v0.4.0 — Next
- [ ] **CMH-X**: Strip AnthropicUsageClient + Keychain API key path (zero outbound HTTP, eliminates ATS surface and Keychain ACL prompts)
- [ ] **CMH-X**: GitHub release v0.3.0 (sign zip, real appcast edSignature, tag on Releases page)
- [ ] **CMH-X**: Session meter % (5h rate-window — delta heuristic from JSONL timestamps)
