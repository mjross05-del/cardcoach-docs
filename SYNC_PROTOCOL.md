# CardCoach Doc Sync Protocol
Adopted 2026-07-16 · Owner: Mike
**Single writable copy.** The cardcoach-docs repo (`main`) is the only writable
copy of the governance doc set. The iCloud copies are tombstones. Claude Chat's
Project knowledge is a read cache fed by GitHub sync.
**Precedence when copies disagree:** repo HEAD > session reports > Chat memory >
Project snapshot. A session that detects a conflict names it and fetches current
state — it does not reason from the stale copy.
**Write paths — only these two:**
1. Claude Code / local: `git pull` FIRST, then edit, commit, `git push origin main`.
2. CoWork: edit in-session, push via the GitHub connector app. Connector pushes
   bypass the local working tree — which is why path 1 pulls first, every time.
**Every session that edits any doc ends its report with a CHAT SYNC block:**
    CHAT SYNC
    commit: <hash>
    files: <name — one-line delta>   (one line per file; "none" is valid)
    chat action: Sync now required? yes / no
Omitting the block is not valid, even when nothing changed.
**Always-current tier:** WORKING_NOTES.md, PIPELINE_AND_DECISIONS.md,
BLOG_OPERATIONS.md. Any commit touching these ⇒ `chat action: yes` ⇒ Mike runs
"Sync now" on the Claude Project before the next Chat session.
**Stamp discipline:** any edit bumps that doc's `Last updated:` header in the
same commit.
**Chat session-open:** Mike pastes the latest CHAT SYNC block (or states "no doc
changes since last sync"). Chat compares against its synced copies and flags
staleness before doing strategy work.
**Numbering:** new WORKING_NOTES item numbers are minted only against repo HEAD,
never against a Chat-side copy.
