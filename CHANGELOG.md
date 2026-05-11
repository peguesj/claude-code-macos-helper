# Changelog

All notable changes to Claude Helper are documented in this file. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
