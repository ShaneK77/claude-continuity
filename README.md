# claude-continuity

Eliminates post-compaction context loss in Claude Code without waiting for the `PreCompact` hook bug to be fixed.

## The problem

Claude Code compacts conversations automatically when the context fills. The `PreCompact` hook — which should fire before compaction so you can save state — has never fired on auto-compaction. The bug has shipped unpatched across 26+ point releases (open: [#50467](https://github.com/anthropics/claude-code/issues/50467), [#13572](https://github.com/anthropics/claude-code/issues/13572)).

The result: after compaction, Claude loses track of what was in flight. Pending proposals, current task, conversational tone — all gone.

## The fix

`UserPromptSubmit` hooks support `additionalContext` — text injected into Claude's context invisibly with every message. This hook fires reliably. After compaction, the context loads in this order:

1. System prompt
2. Compacted summary
3. CLAUDE.md
4. Memory files
5. **UserPromptSubmit injection ← here**

Injecting at position 5 means the session state lands *after* the compacted summary, at the highest-attention position. The summary can't override it.

## Architecture

Two hooks work together:

**`Stop` hook** (`session-state-capture.sh`) — runs at end of every turn. Writes timestamp, git branch, and dirty files to `session-last-turn.md`. Lightweight: one bash process + two git subprocesses.

**`UserPromptSubmit` hook** (`session-state-inject.sh`) — runs before every message. Reads `session-state.md` (rich conversational context, written by Claude) and `session-last-turn.md` (system state, written by the hook), injects both as `additionalContext`. Skips silently if no `session-state.md` exists or if it's older than 4 hours (stale checkpoint from a previous session).

Claude writes `session-state.md` at natural pausing points during a session. The hooks handle the injection automatically.

## Installation

```bash
git clone https://github.com/<you>/claude-continuity
cd claude-continuity
chmod +x install.sh
./install.sh
```

Requires `jq` for automatic `settings.json` merging. Without it, the script prints what to add manually.

## Per-project setup

For each project you want session continuity on:

```bash
# Find your project slug: replace / with - in the absolute path
# e.g. /Users/you/Projects/myapp → -Users-you-Projects-myapp

mkdir -p ~/.claude/projects/<project-slug>/memory
cp templates/session-state.md ~/.claude/projects/<project-slug>/memory/
```

Then tell Claude to fill in `session-state.md` at pausing points. Add this to your `CLAUDE.md`:

```markdown
## Session Continuity

At natural pausing points — before responding to input, at the end of a major task,
when context is getting long — write or update `memory/session-state.md`.

Checkpoint must contain:
- **Last 3-5 exchanges**: paraphrase actual content, not just topics
- **Pending items**: anything said that hasn't been responded to yet, verbatim
- **Active task**: what is being worked on, or what you're waiting for
- **Decisions in flight**: things being discussed but not yet decided
- **Tone**: user's current state — frustrated, focused, exploring?

Test: "If I woke up with only this, could I seamlessly continue?" If no, keep writing.
```

## Token cost

The injection adds ~600 tokens per message while the checkpoint is fresh (~$0.002/message at Sonnet rates). Older than 4 hours: zero cost, hook exits immediately without spawning Python.

Keep `session-state.md` tight — 150-200 words is enough for most sessions.

## How the JSONL fallback works

Every message — pre- and post-compaction — is preserved in the session JSONL at:

```
~/.claude/projects/<project-slug>/<session-id>.jsonl
```

If the checkpoint is incomplete, recover with:

```python
# Context-safe tail read: last 400 lines, truncate each to 2000 chars, stop at 40k total
lines = open(jsonl_path).readlines()[-400:]
out, total = [], 0
for line in reversed(lines):
    t = line[:2000] + ('[...TRUNCATED]' if len(line) > 2000 else '')
    if total + len(t) > 40000:
        break
    out.append(t)
    total += len(t)
print(''.join(reversed(out)))
```

Never tell the user "that was lost in compaction" without checking the JSONL first.

## Limitations

- Rich conversational content (`session-state.md`) still requires Claude to write it — the hook can't generate it. The injection mechanism is reliable; the content quality depends on discipline.
- If `PreCompact` is ever fixed in Claude Code, you can wire `session-state.md` writes to that hook instead and remove the behavioral dependency.
- The 4-hour staleness threshold is configurable in `session-state-inject.sh` (`AGE` check).

## Inspired by

[How I Optimized Conversation Memory Snapshots in OpenClaw](https://x.com/BenjaminBadejo/status/2025587066436784636) — the checkpoint structure and JSONL recovery method come from this post. The `UserPromptSubmit` injection approach is a Claude Code-specific adaptation that works around the broken `PreCompact` hook.
