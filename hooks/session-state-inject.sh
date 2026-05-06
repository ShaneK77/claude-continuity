#!/bin/bash
# Injects session-state.md and session-last-turn.md as additionalContext
# with every user prompt, placing checkpoint at highest-attention position.

PROJECT_SLUG=$(echo "$CLAUDE_PROJECT_DIR" | tr '/' '-')
MEMORY_DIR="$HOME/.claude/projects/$PROJECT_SLUG/memory"
STATE_FILE="$MEMORY_DIR/session-state.md"
TURN_FILE="$MEMORY_DIR/session-last-turn.md"

# Nothing to inject if no state file exists
[ -f "$STATE_FILE" ] || exit 0

# Skip if checkpoint is stale (older than 4 hours) — avoids injecting
# context from a previous session into every message of a new one
MTIME=$(stat -f %m "$STATE_FILE" 2>/dev/null || stat -c %Y "$STATE_FILE" 2>/dev/null)
NOW=$(date +%s)
AGE=$(( NOW - MTIME ))
[ "$AGE" -gt 14400 ] && exit 0

python3 - "$STATE_FILE" "$TURN_FILE" <<'PYEOF'
import json, sys, os

parts = []

state_file = sys.argv[1] if len(sys.argv) > 1 else ''
turn_file  = sys.argv[2] if len(sys.argv) > 2 else ''

try:
    with open(state_file) as f:
        content = f.read().strip()
    if content:
        parts.append('SESSION STATE (pre-compaction checkpoint):\n\n' + content)
except Exception:
    pass

try:
    with open(turn_file) as f:
        turn = f.read().strip()
    if turn:
        parts.append('SYSTEM STATE (last turn):\n' + turn)
except Exception:
    pass

if not parts:
    sys.exit(0)

print(json.dumps({
    'hookSpecificOutput': {
        'hookEventName': 'UserPromptSubmit',
        'additionalContext': '\n\n---\n\n'.join(parts)
    }
}))
PYEOF
