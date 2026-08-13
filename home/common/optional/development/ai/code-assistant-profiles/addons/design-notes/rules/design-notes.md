Durable engineering documentation lives under `docs/`, at two scopes. Read what is already there before adding to it, and match the conventions the sibling files use.

Project scope — describes the repo, independent of any current task:

- `docs/adr/` — architecture decision records, MADR 3.0, the dominant artifact. Check existing files for the numbering sequence and which naming form that repo uses (`0001-slug.md` or `ADR-001-slug.md`).
- `docs/steering/` — `product.md`, `tech.md`, `structure.md`. Read these before design or architecture work when they exist; `/steering-setup` creates them.

An ADR records **why**: the decision, and the alternatives rejected with the reason each lost. Write it when the decision settles — just before building — not as upfront planning. What is being built and how it will be verified lives in the JIRA ticket the branch is named for, so do not restate the ticket as a requirements document in the repo.

Work scope — `docs/work/<topic>/`, one folder per piece of work, holding whatever documents that work needs: a design or plan when one is warranted, an interview write-up, ad-hoc notes. There is no required set of files and no task list. Most work produces only an ADR.

When several decisions interact, a design document earns its place. Follow the Google design-doc convention: goals and explicit **non-goals**, the proposed design, alternatives considered with the trade-offs that decided against them, open questions left standing as open, and risks. Expect it to write up a prototype that already exists rather than to precede one, and expect it to accumulate addenda as implementation uncovers things — addenda supersede the original text, so read them.
