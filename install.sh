#!/bin/bash
# Installs claude-continuity hooks into ~/.claude/hooks/ and wires them
# into ~/.claude/settings.json.
#
# Requirements: bash, jq, python3

set -e

HOOKS_DIR="$HOME/.claude/hooks"
SETTINGS="$HOME/.claude/settings.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── 1. Copy hooks ────────────────────────────────────────────────────────────
mkdir -p "$HOOKS_DIR"
cp "$SCRIPT_DIR/hooks/session-state-capture.sh" "$HOOKS_DIR/"
cp "$SCRIPT_DIR/hooks/session-state-inject.sh"  "$HOOKS_DIR/"
chmod +x "$HOOKS_DIR/session-state-capture.sh" "$HOOKS_DIR/session-state-inject.sh"
echo "✓ Hooks copied to $HOOKS_DIR"

# ── 2. Update settings.json ──────────────────────────────────────────────────
if [ ! -f "$SETTINGS" ]; then
    echo '{}' > "$SETTINGS"
fi

# Check for jq
if ! command -v jq &>/dev/null; then
    echo ""
    echo "jq not found — add the following to $SETTINGS manually:"
    echo ""
    cat <<'EOF'
"hooks": {
  "Stop": [{ "matcher": "", "hooks": [{ "type": "command", "command": "$HOME/.claude/hooks/session-state-capture.sh" }] }],
  "UserPromptSubmit": [{ "matcher": "", "hooks": [{ "type": "command", "command": "$HOME/.claude/hooks/session-state-inject.sh" }] }]
}
EOF
    exit 0
fi

# Merge hooks into existing settings without clobbering other keys
UPDATED=$(jq '
  .hooks.Stop += [{"matcher": "", "hooks": [{"type": "command", "command": "$HOME/.claude/hooks/session-state-capture.sh"}]}] |
  .hooks.UserPromptSubmit += [{"matcher": "", "hooks": [{"type": "command", "command": "$HOME/.claude/hooks/session-state-inject.sh"}]}]
' "$SETTINGS")

echo "$UPDATED" > "$SETTINGS"
echo "✓ Hooks registered in $SETTINGS"

# ── 3. Remind user to create session-state.md per project ───────────────────
echo ""
echo "Done. For each project that should use session continuity:"
echo "  1. Create the memory directory:"
echo "     mkdir -p ~/.claude/projects/<project-slug>/memory"
echo "  2. Copy the template:"
echo "     cp $SCRIPT_DIR/templates/session-state.md ~/.claude/projects/<project-slug>/memory/"
echo ""
echo "The inject hook only fires when session-state.md exists and is under 4 hours old."
echo "See README.md for full setup instructions."
