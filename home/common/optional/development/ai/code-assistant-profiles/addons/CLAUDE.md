# Authoring addons and skills

Reference for adding new addons (`addons/<name>/`) or skills under existing addons. Reflects the skill-listing mechanics and best practices verified May 2026.

## Addon layout

```
addons/<name>/
├── default.nix                       # registers programs.code-assistant-profiles.addons.<name>
├── skills/<skill-name>/
│   ├── prompt.md                     # required; YAML frontmatter + body
│   └── resources/                    # optional reference files (resourcesRoot)
├── agents/<agent-name>.md            # optional
└── rules/<rule-name>.md              # optional
```

`default.nix` template (skill-only, no resources):

```nix
_: {
  programs.code-assistant-profiles.addons.<name> = {
    skills."<skill-name>".prompt.source = ./skills/<skill-name>/prompt.md;
  };
}
```

After adding a new addon directory: `git add -N` it before `nix flake check` — flakes ignore untracked files. Then add the addon name to `profiles.default.include` in `../default.nix` (or to a more specific profile).

## Skill description: hard mechanics

- **Per-skill listing cap: 1,536 characters** (raised from 250 in Claude Code v2.1.105). Longer descriptions are truncated at startup and a warning is printed.
- **Total listing budget: 1% of the context window** by default, shared across all skills (`SLASH_COMMAND_TOOL_CHAR_BUDGET` env var to raise). On a 200K window that's ~2,000 tokens for *all* skills combined.
- **Selection text = `description` + `when_to_use`** concatenated, capped together at 1,536 chars in Claude Code.
- Only `name` + `description` are pre-loaded into the system prompt. Everything else (body, resources) loads only after the skill triggers — too late to influence selection.

## Budgets are checked at build time

`programs.code-assistant-profiles.budgets` measures each resolved profile and
reports over-budget content as a home-manager warning. Set `enforce = "error"` to
fail the build instead, or `"off"` to skip the check. The defaults:

| Budget | Default | What it measures |
| ------ | ------- | ---------------- |
| `alwaysOn.lines` | 200 | `instructions` plus every rule *without* `paths`. [Anthropic's documented target](https://code.claude.com/docs/en/memory); past it, adherence drops. |
| `alwaysOn.characters` | 20000 | The same content, ~5k tokens. Catches the long unwrapped lines most rules here are written in, which the line count under-reports. |
| `description.total` | derived | Every skill `description` + `when_to_use` and every agent `description` combined — the shared listing budget. Left null it derives from `contextWindow`: 1% of the window, at ~4 characters per token. |
| `description.characters` | 1536 | One entry's selection text, the point where Claude Code truncates it. |
| `contextWindow` | 200000 | Window of the model the profiles actually run against. This repo sets 1000000 (Opus 5), giving a 40000-character listing budget. Null drops the derived check. |

A rule with `paths` is outside `alwaysOn` entirely: it loads only when Claude
opens a matching file. That is the first thing to reach for when the always-on
budget complains — then moving detail into a skill body.

`description.total` counts skills you never invoke as well as ones you do, and
vendored skills from flake inputs count too without being shortenable in place.
Before dropping one as unused, check **both** invocation paths — a `Skill` tool
call and a `/name` slash command are recorded separately, and querying only the
first undercounts.

Set `contextWindow` to the window you really run against. Budgeting a 1M-token
model as though it were 200K only manufactures warnings.

## Description: best practices

Aim for **150 characters or less**, hard ceiling 200. Front-load trigger keywords in the first 50 characters.

| Pattern         | Length     | Status               |
| --------------- | ---------- | -------------------- |
| Anthropic examples | 140–165 ch | Target band          |
| Lean recommended   | 110 ch     | Excellent            |
| Typical            | 200–400 ch | Acceptable, watch budget |
| > 400 ch           | —          | Bloated, will erode shared budget |

What the description must do:

1. State **what the skill does** in one verb phrase.
2. List the **core trigger concepts** once. Claude does semantic matching — synonyms aren't free, naming the concept is enough.
3. Optionally end with **"Use when …"** to add explicit trigger context.

What it must not do:

- Enumerate paraphrases ("e.g. 'start the server', 'tail the logs', 'run it in a pane', …"). One canonical phrase is sufficient.
- Marketing prose ("comprehensive", "powerful", "modern").
- Repeat what the body already says.

Required mechanics:

- **Third person.** "Generates X" / "Reviews X" — not "I help you" or "You can use this".
- Avoid apostrophes inside single-quoted YAML scalars — the resolver's parser doesn't unescape `''`. Use double quotes or rephrase ("can't" → "cannot").
- Avoid YAML block scalars (`|`, `>`) for these fields — use a single-line string.

### Side-by-side

Bloated (380 ch): *"A comprehensive code review skill that analyzes your codebase for security vulnerabilities, performance issues, code smells, accessibility problems, and architectural concerns…"*

Lean (110 ch): *"Reviews code for security, performance, and architecture issues. Use when reviewing PRs or pre-ship changes."*

## `when_to_use`: when (not) to use it

The resolver maps `when_to_use:` frontmatter → `whenToUse` option, which renders into:

- **Claude Code:** `when_to_use:` field, concatenated with `description` for selection (shares 1,536 cap).
- **opencode:** appended to `description` (this module concatenates them with `\n\n`).

Use `when_to_use` only when:

- You have genuinely distinct trigger phrases or example requests that don't fit the description's flow.
- The combined `description + when_to_use` still stays under 200 chars.

Skip it when:

- The description already names the trigger concepts. Adding `when_to_use` then is pure padding sharing the same cap.
- You'd be enumerating synonyms — that doesn't help selection meaningfully.

## Body content (post-trigger, loads only when the skill fires)

- Keep **under 500 lines**. Anthropic's published cap.
- Body content costs tokens for the whole session once loaded.
- Default to **no `## When to Use` section in the body** — selection happens before the body is read, so trigger guidance there is useless. Use a `## Scope` section instead to document boundaries (in/out) once the skill is active.
- **Progressive disclosure:** large reference material goes in `resources/references/<topic>.md`, linked one level deep from `prompt.md`. Don't nest references — Claude may only partially read deeply nested files.
- Reference files >100 lines should start with a table of contents.

## Frontmatter fields supported by the resolver

Reads from `prompt.md` frontmatter and maps to nix options ([resolve-profile.nix](../../../../../modules/home/programs/code-assistant-profiles/resolve-profile.nix)):

| Frontmatter key            | Nix option        | Notes                                                |
| -------------------------- | ----------------- | ---------------------------------------------------- |
| `name`                     | `name`            | Defaults to skill directory name.                    |
| `description`              | `description`     | Required for selection. See cap above.               |
| `when_to_use`              | `whenToUse`       | Optional. Concatenated with description.             |
| `argument-hint`            | `argumentHint`    | Shown in autocomplete (Claude Code).                 |
| `allowed-tools`            | `allowedTools`    | YAML list. Pre-approves these tools while active.    |
| `disable-model-invocation` | `invocation.model` (inverse) | Set `true` to make the skill manual-only. |
| `effort`                   | `reasoningEffort` | `low`/`medium`/`high`/`xhigh`/`max`.                 |
| `paths`                    | `paths`           | Glob list; auto-activates only on matching files.    |
| `model`, `agent`, `context`, `version` | as named | Pass-through to Claude Code.            |

## Workflow checklist

When adding a new skill:

1. Write `prompt.md` with a ≤150-char description in third person, naming trigger concepts once.
2. Body in `## Scope`, `## Steps`, etc. Under 500 lines. No `## When to Use`.
3. Resources in `resources/references/<topic>.md` if needed; one level deep, ToC if >100 lines.
4. Register in `addons/<name>/default.nix` (use `resourcesRoot` if there are resources).
5. `git add -N` the new files.
6. Add the addon to `profiles.default.include` (or a more specific profile).
7. `nix flake check --no-build` to verify, and read the warnings — the budget check reports there.
8. Inspect rendered output:
   `nix eval --impure --raw --expr 'let f = builtins.getFlake "/home/addg/nix-config"; in builtins.readFile "${f.nixosConfigurations.<host>.config.home-manager.users.<user>.programs.opencode.skills.<skill>}/SKILL.md"'`

## Sources verified May 2026

- [Skill authoring best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)
- [Claude Code skills docs](https://code.claude.com/docs/en/skills) — frontmatter reference
- [claudefa.st — Skill listing budget](https://claudefa.st/blog/guide/mechanics/skill-listing-budget) — concrete length guidance
- [Issue #47627](https://github.com/anthropics/claude-code/issues/47627) — 250→1536 cap change history
- [agentskills.io specification](https://agentskills.io/specification) — open standard fields
