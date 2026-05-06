# Session State

Pre-compaction snapshot — point-in-time capture of working state, written before compaction fires or at natural pausing points.

**Written at:** [timestamp]
**Session:** [project / topic]

## How to use this file
If resuming after compaction or restart, this is your starting point. If the timestamp is recent and you're in the same working session, trust it. If significant time has passed, cross-reference with today's daily memory file.

Recovery path:
1. Read this file
2. Read today's daily memory file (`memory/YYYY-MM-DD.md`)
3. If needed, check the session JSONL at `~/.claude/projects/<project-slug>/<session-id>.jsonl`

---

## Working State

### Current Task
[What is actively being worked on. If idle, what you're waiting for.]

### Last 3-5 Exchanges
[Paraphrase actual conversation — not just topics. What did the user say? What did you say? If you proposed something, write what you proposed.]

### Pending Items
[Anything said that the user hasn't responded to yet. Capture VERBATIM. These are the #1 casualty of compaction.]

### Decisions in Flight
[Things being discussed but not yet decided.]

### Tone
[Is the user frustrated? Focused? In a hurry? Exploring? This matters for continuity.]

### Key Context
[Any other important state: active files, open issues, relevant background, scheduled items.]
