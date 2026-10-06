---
name: gitlab-mr
description: "Finds a GitLab merge request with glab, reads its diff and threads, and posts review findings as notes on exact diff lines."
argument-hint: "[MR number or branch, default: current branch]"
---

# GitLab merge requests

MR: $ARGUMENTS

## Scope

In: finding an MR, reading its metadata, diff and threads, posting review findings as line or general notes, replying, resolving threads, editing and deleting your own notes.

A thread is what GitLab calls a discussion; glab flags and ids use `discussion`.
Out: reviewing the code itself (use `/review-branch`), GitHub PRs (`/review-pr`), merging or approving.

## Find the MR

1. Pass `-R <group/…/repo>` on every call. Work clones store the remote as `git@gitlab-work:…`, an ssh alias glab may not map; derive the path from the ghq location (`~/Projects/code/gitlab.com/<group/…/repo>`).
2. No MR given: use the current branch (`git branch --show-current`). A number: that MR. Otherwise: treat it as a branch name.
3. Find it from the branch: `glab mr list -R <repo> --source-branch <branch>`. No open MR for the branch: say so and stop.
4. Read what matters in one call:
   `glab mr view <N> -R <repo> -F json | jq '{iid, title, sha, author: .author.username, reviewers: [.reviewers[].username], draft, target_branch}'`

## Before any line note

- Confirm the MR head is the commit you reviewed: `.sha` from `mr view` must equal `git rev-parse HEAD`. If it differs, re-check line numbers against the MR's commit, not your checkout.
- A line note only attaches to a line that appears in the MR diff. List the added ranges per file:
  `git diff <target>...HEAD -U0 -- <file> | grep '^@@'` — `+a,b` means new-side lines a to a+b-1.
- A finding on a line outside the diff: anchor on the nearest added line in that file and name the real `file:line` in the text.
- The file is not in the diff at all: post a general note instead (no `--file`).
- Lines removed by the MR take `--old-line` instead of `--line`.

## Post

1. Show the user the review findings, then ask once whether to post them as notes on the MR.
2. Post only the findings the user picks, all in one go. If they answer with something else or move on, post nothing and drop the offer.

```
glab mr note create <N> -R <repo> --file <path> --line <new-line> -m "<body>"   # line note
glab mr note create <N> -R <repo> < body.md                                      # general note, long body
```

- Backticks inside a double-quoted `-m` must be backslash-escaped; for anything with code or several lines, write the body to a file and pipe it on stdin.
- `glab mr note` is experimental (glab 1.114); if a flag is rejected, check `glab mr note create --help` before retrying.

## Verify

Confirm every note attached where intended. `glab api user | jq -r .username` gives `<you>`.

```
glab mr note list <N> -R <repo> -F json | jq -r '.[] | .notes[] | select(.author.username=="<you>") | "\(.id) \(.type) \(.position.new_path // "general"):\(.position.new_line // "")"'
```

`DiffNote` is a line note; `DiscussionNote` is a general note. Report the URLs and the file:line table to the user.

## Edit, reply, resolve

- Edit or delete your note: `glab mr note update <N> <note-id> -R <repo> < body.md`, `glab mr note delete <N> <note-id> -R <repo>`. The MR comes first despite what `--help` says; the documented order 404s. Delete only notes the user asked to remove.
- Reply in a thread: `--reply <discussion-id prefix, 8+ chars>`; find ids with `glab mr note list <N> -R <repo> -F json | jq -r '.[].id'`.
- Resolve or reopen a thread: `glab mr note resolve <discussion-id> <N> -R <repo>` / `reopen`.
- If the user deleted a note in the UI, re-list before acting; never re-post a removed note unless asked.
