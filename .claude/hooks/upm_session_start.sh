#!/usr/bin/env bash
# upm_session_start.sh — SessionStart hook for Claude Helper (claude-code-macos-helper)
#
# Purpose:
#   `/upm status` and `/upm sync` are Claude Code SKILLS (no shell entrypoint),
#   so this hook cannot run them directly. Instead it emits
#   hookSpecificOutput.additionalContext, which Claude Code injects into the
#   session as a system reminder, instructing the running session to invoke
#   `/upm status` followed by `/upm sync` at the start of the session.
#
# Contract:
#   - Idempotent: prints the same deterministic additionalContext every run.
#   - Fail-soft: NEVER blocks session start. Always exits 0, even on error.
#   - Errors are logged to .claude/hooks/logs/upm_session_start.log
#
# Output (stdout) on success: a single JSON object of the form
#   {"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"..."}}
set -uo pipefail

# Resolve this script's directory robustly so logging works regardless of CWD.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" >/dev/null 2>&1 && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/upm_session_start.log"

# Best-effort logging helper. Never fails the hook.
log() {
  { mkdir -p "$LOG_DIR" 2>/dev/null && \
      printf '%s [upm_session_start] %s\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo unknown)" "$1" \
        >> "$LOG_FILE" 2>/dev/null; } || true
}

# Emit a valid (empty-context) SessionStart payload and exit 0 on any failure
# so the session is never blocked.
emit_empty_and_exit() {
  printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":""}}'
  exit 0
}

trap 'log "unexpected error (line $LINENO); failing soft"; emit_empty_and_exit' ERR

REMINDER='<system-reminder>
UPM session bootstrap for claude-code-macos-helper (Claude Helper).
Before doing anything else in this session, run these two Claude Code skills in order:
1. /upm status   — unified view of prd.json x Plane x CLAUDE.md x git
2. /upm sync     — detect and repair drift across tracking systems
Run /upm status first, review the output, then run /upm sync. If either skill is unavailable or errors, note it and continue with the user request normally.
</system-reminder>'

# Build the JSON payload safely with Python (handles all escaping). Fall back
# to an empty payload if Python is unavailable or serialization fails.
PAYLOAD="$(
  REMINDER="$REMINDER" python3 - <<'PY' 2>/dev/null
import json, os
ctx = os.environ.get("REMINDER", "")
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": ctx,
    }
}))
PY
)" || PAYLOAD=""

if [ -z "${PAYLOAD:-}" ]; then
  log "failed to build JSON payload (python3 missing or error); emitting empty context"
  emit_empty_and_exit
fi

log "emitted additionalContext instructing session to run /upm status then /upm sync"
printf '%s\n' "$PAYLOAD"
exit 0
