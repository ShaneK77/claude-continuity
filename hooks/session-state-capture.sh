#!/bin/bash
# Writes minimal system state to session-last-turn.md at end of each turn.
# The AI writes rich conversational context to session-state.md separately.

PROJECT_SLUG=$(echo "$CLAUDE_PROJECT_DIR" | tr '/' '-')
MEMORY_DIR="$HOME/.claude/projects/$PROJECT_SLUG/memory"

# Only run if the memory dir exists (project has session state set up)
[ -d "$MEMORY_DIR" ] || exit 0

BRANCH=$(git -C "$CLAUDE_PROJECT_DIR" branch --show-current 2>/dev/null || true)
DIRTY=$(git -C "$CLAUDE_PROJECT_DIR" status --short 2>/dev/null | head -10 || true)

{
    printf 'Last turn: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    [ -n "$BRANCH" ] && printf 'Branch: %s\n' "$BRANCH"
    [ -n "$DIRTY" ] && printf 'Dirty files:\n%s\n' "$DIRTY"
} > "$MEMORY_DIR/session-last-turn.md"

exit 0
