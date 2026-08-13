# design-notes

Conventions and tooling for a repo's durable engineering documentation, at two
scopes.

- **Project scope** — `docs/adr/` and `docs/steering/`, describing the repo itself
- **Work scope** — `docs/work/<topic>/`, one folder per piece of work

There is no pipeline here and no task tracking. Nothing requires a document to
exist before work starts, and most work produces only an ADR.

This is a separate concern from `spec-driven-dev`, which implements a gated
spec → design → tasks → TDD flow and owns the `.sdd/` directory. That addon
stands on its own; this one is neither a replacement for it nor derived from it.
The `default` profile includes this addon.

## Layout

```
docs/
├── adr/                           ADRs, MADR 3.0 — the dominant artifact
│   ├── 0001-slug.md                 (both naming forms occur; match siblings)
│   └── ADR-001-slug.md
├── steering/                      project context — read before design work
│   ├── product.md                   users, value, workflows
│   ├── tech.md                      stack, build/test, conventions
│   └── structure.md                 layout, entry points, boundaries
└── work/<topic>/                  one folder per piece of work
    └── *.md                         a design or plan when warranted,
                                     an interview write-up, ad-hoc notes
```

**ADRs record *why*** — the decision and the alternatives rejected — written when
a decision settles, just before building. The *what and how* lives in the JIRA
ticket the branch is named for, which is why no `requirements.md` gets written.

**Design documents follow the [Google convention](https://www.industrialempathy.com/posts/design-docs-at-google/):**
goals and explicit non-goals, proposed design, alternatives considered with
trade-offs, open questions left open, risks. They are written up *from* a
prototype rather than before one, and accumulate addenda as implementation
uncovers things — addenda supersede the original text, so read them.

**Task lists are historical.** Some older folders contain a `tasks.md`; nothing
maintains them. Treat one as a note about what was once planned, not current
state.

## Commands

| Command | Invocation | Purpose |
|---|---|---|
| `/steering-setup` | manual only | Write `product.md`/`tech.md`/`structure.md` from the project. One-time per repo. |
| `/interview [topic]` | manual or model | Research the codebase, then interview on the decisions only a human can make. Offers to save the summary as an artifact. |
| `/notes-status [folder]` | manual only | Summarise `docs/` — steering, ADRs, and work folders with the documents they hold |

Writing ADRs lives in the `architecture` addon (`/adr`, `architecture-standards`,
`system-architect`); quality checks live in `code-review` (`shortcut-hunter`,
`silent-failure-hunter`, the `quality-standards` rule). Both reviewers below
preload `architecture-standards`, so include `architecture` alongside this addon.

## Agents

Both are on-demand — nothing spawns them automatically.

| Agent | Purpose |
|---|---|
| `requirements-reviewer` | Reviews a requirements or spec document for clarity, completeness, testability. Read-only. |
| `design-reviewer` | Reviews a design or plan document for feasibility and fit with stated intent. Read-only. |

They restrict tools via `disallowedTools: Write, Edit, Bash`.

Both are document-agnostic: they take whichever document a repo actually wrote
(`design.md` or `plan.md`, `requirements.md` or `spec.md`) and treat a missing
companion document as absent context rather than a defect. `design-reviewer`
skips its intent-alignment criterion and redistributes the weight when nothing
states what the design must satisfy.

## Hook

One hook, `session-start.sh`, wired to `SessionStart` and to `SessionStart` with
`matcher = "compact"`. It names the repo's `docs/` contents — steering documents,
ADR count, and work folders with the documents they contain — so existing
artifacts get read instead of duplicated. It names files rather than inlining
them, and exits silently when the repo has no `docs/`.

## Rule

`design-notes` — what `docs/` holds at each scope, and how to treat it.
