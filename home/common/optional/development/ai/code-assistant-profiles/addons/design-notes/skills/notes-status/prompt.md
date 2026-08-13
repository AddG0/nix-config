---
name: notes-status
description: "Summarises a repo's engineering documentation — steering, ADRs, and per-topic work folders under docs/."
invocation:
  model: false
allowed-tools: [Read, Glob, Grep]
argument-hint: "[folder-name]"
---

# Documentation Status

Report what engineering documentation this repo holds. Treat a partial set of
documents as normal — do not report missing files as a problem.

| | location |
|---|---|
| ADRs | `docs/adr/` |
| project context | `docs/steering/` |
| per-topic work | `docs/work/<topic>/` |

## When `$1` is empty — summarise the repo

1. Glob `docs/steering/*.md`; report which of the three documents exist, and note
   if none do (`/steering-setup` creates them).
2. Glob `docs/adr/*.md` and count.
3. Glob `docs/work/*/` for work folders.
4. Print:

   ```markdown
   ## Documentation — {repo name}

   **Steering**: {docs present, or "none — /steering-setup to create"}
   **ADRs**: {count} (latest: {highest-numbered filename})

   | Folder | Documents | Last touched |
   |--------|-----------|--------------|
   | {name} | {docs present} | {git log -1 date for the folder} |
   ```

Order work folders newest-first — the most recently touched is the likely
in-flight one.

## When `$1` names a folder

1. Resolve `$1` under `docs/work/$1/`. If it does not exist, list what does and
   stop. `$1` may also be `adr` or `steering`.

2. Read every `.md` in it and report, per document, a one-line summary of what it
   covers. Note explicitly if a design document carries addenda — those record
   decisions made during implementation and are easy to miss.

3. Summarise what the documents indicate is done and what remains, from their own
   content — there is no task-tracking artifact to read.

   ```markdown
   ## $1

   | Document | Covers |
   |----------|--------|
   | {file} | {one line} |

   **State**: {what the documents suggest is settled and what is open}
   ```

Report state and stop. Do not propose a command to continue.
