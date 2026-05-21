# Claude Helper v0.2.0 — Session Handoff Memo

**Generated**: 2026-05-21  
**Version at handoff**: 0.2.0 (CFBundleVersion 2), HEAD `3e14e7b` on `main`  
**Tests**: 10/10 passing

---

## What was accomplished

All v0.2.0 work committed. Deliverables:

- **Live telemetry** (`FileSystemWatcher.swift`): FSEvents DispatchSource on `~/.claude/stats-cache.json` + `usage-snapshots/` dir. Meters refresh within 500 ms of any hook write. 60 s poll timer kept as fallback only.
- **Corrected Max 20x week limits**: all-models 63 M (was 252 M), Sonnet 33 M (was 84 M). Empirically derived from observed claude.ai percentages. Max 5× and 20× share the same weekly quota; multiplier scales per-session rate only.
- **Session/Today meter `limit=0`**: eliminates misleading bar comparing daily cumulative against a single 5-hour rate-window cap.
- **Liquid-glass AppIcon**: 10 PNGs via `scripts/generate_icon.py` (rsvg-convert), assembled via `iconutil` into `AppIcon.icns`, bundled by `build-app.sh`. Dark charcoal squircle, copper C-arc with glow filter, frosted radial gradient, specular top-edge highlight, squircle border shimmer.
- **Sparkle wiring**: `SUPublicEDKey` in `Info.plist`, `docs/appcast.xml` on GitHub Pages. Resolves 404 but NOT fully functional yet (see known issues).
- Prior session also merged: `stats-cache` as primary source, per-session snapshot isolation, `AnthropicUsageClient` fallback, spend forecast sanity fix.

---

## Current state

**Works**: menubar meters, live FSEvents updating, profile switching, Keychain storage, spend ledger, auto-reload reminders, AppIcon, LaunchAtLogin.

**Doesn't work / incomplete**:

| Issue | Notes |
|-------|-------|
| "Check for Updates" | `appcast.xml` has `PLACEHOLDER_SIGN_ON_RELEASE`. Sparkle rejects download until real signed zip. No v0.2.0 GitHub release exists. |
| Session meter % | Shows raw count, no bar. `stats-cache` daily ≠ 5-hour rate window. Need live Admin API or window-delta heuristic. |

---

## Critical next TODO: finish Sparkle release

1. `make release` → produces universal `.app` in `dist/`
2. Zip: `zip -r ClaudeHelper-0.2.0.zip dist/ClaudeHelper.app`
3. Sign: `.build/artifacts/sparkle/Sparkle/bin/sign_update ClaudeHelper-0.2.0.zip` → copy `sparkle:edSignature` output
4. Update `docs/appcast.xml`: replace `PLACEHOLDER_SIGN_ON_RELEASE`, set `length` to zip byte count, set `url` to `https://github.com/peguesj/claude-code-macos-helper/releases/download/v0.2.0/ClaudeHelper-0.2.0.zip`
5. Commit + push `docs/appcast.xml`
6. Create GitHub tag `v0.2.0`, attach signed zip as release asset
7. Test via menubar "Check for Updates"

---

## Known issue: Keychain ACL prompt loops on dev builds

**Symptom**: macOS shows "Claude Helper wants to use your confidential information stored in `io.pegues.ClaudeHelper.<UUID>`" on every launch (or every telemetry poll) when running a freshly-rebuilt dev binary.

**Root cause**: `KeychainHelper.set()` adds items with `kSecAttrAccessibleAfterFirstUnlock` but without an explicit `kSecAttrAccess` ACL. macOS auto-generates an ACL tied to the code signature of the creating binary. Ad-hoc re-signs (`codesign --sign -`) produce a fresh signature each build → subsequent runs look like a "new app" → Keychain prompts. With FSEvents now firing `refreshOnce()` up to ~1/sec, `profileStore.apiKey(for:)` is called far more frequently and floods the prompt.

**The fix (deferred to next session)**: Add `kSecUseDataProtectionKeychain: true` to all queries in `KeychainHelper`. This moves items to the data-protection keychain, which uses accessibility-level protection (no per-app ACL checks, no dialog). Existing login-keychain items need a one-time read→write migration on first launch after the change.

```swift
// In KeychainHelper.set / get / delete — add to every query dict:
kSecUseDataProtectionKeychain as String: true
```

Migration on first run:
1. Try `get()` with `kSecUseDataProtectionKeychain: true` → if found, done
2. Try `get()` without flag → if found, re-write with flag, delete old item

**Impact until fixed**: Click "Always Allow" once in the dialog during development. Production builds signed with Developer ID will not re-prompt because the signature is stable across builds.

---

## Plane state

All 29 CMH issues are Done as of this session (CMH-13..CMH-20 created for v0.2.0 work). Plane is fully aligned with git.
