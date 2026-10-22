# Close the code-assistant-profiles mapping gaps

Decisions are in ADR 0005. Audit of 2026-10-20 against Claude Code 2.1.303,
codex-cli 0.163.0, opencode 1.19.0. Paths are relative to
`modules/home/programs/code-assistant-profiles/` unless rooted.

## Goals

- Every feature each tool documents is expressible, typed where the ADR says.
- Nothing is emitted that the tool ignores, misreads or calls deprecated.

## Non-goals

- Claude Code managed tier (`/etc/claude-code`): ADR 0005.
- Shared cross-tool hooks: ADR 0005.

## Already done

Agent `model` for opencode passes only `provider/model`; effort accepts
`xhigh`; opencode remote MCP `headers`; LSP `extensionToLanguage` required.

## Phases

Each phase lands with regression tests in `tests.nix` (or the module's own).

### 1. Output the tools ignore or deprecate (~30 min)

- `home/common/optional/development/ai/claude-code/default.nix`:
  `includeCoAuthoredBy` → `attribution` (`commit`/`pr`).
- `targets/claude-code.nix`: stop emitting agent `category` and skill
  `version` (move it to `metadata.version`).
- Codex skills dir: `$CODEX_HOME/skills` → `~/.agents/skills`
  (`targets/codex.nix:46,136`).
- `home/common/optional/development/ai/opencode/default.nix:31`:
  `opencode/plugin/` → `opencode/plugins/`.

### 2. Skill invocation and tool limits (~2 h)

- opencode: write `metadata."opencode/autoinvoke"` / `"opencode/slash"` in
  SKILL.md instead of the prose line, and stop duplicating user-invocable
  skills into `commands/` (`targets/opencode.nix`, the command-rendering block).
- Codex: write `agents/openai.yaml` with `policy.allow_implicit_invocation`
  per skill; stop emitting Claude-only SKILL.md fields
  (`targets/codex.nix:51-81`).
- opencode agent `tools` allowlist → `permission` map (`"*": deny` plus each
  allowed tool). Map Claude names (`Write`→`edit`, `Agent`→`task`,
  `mcp__s__t`→`s_t`) for `disallowedTools` too.

### 3. Codex subagents (~afternoon)

- Render shared agents to `$CODEX_HOME/agents/<name>.toml` (`name`,
  `description`, `developer_instructions`, `model`,
  `model_reasoning_effort`) instead of skills (`targets/codex.nix:110-118`).
- Codex accepts `xhigh`, `max`, `ultra`; decide whether `ultra` joins the
  shared enum.

### 4. Optional fields (~1 day)

Shared and typed (two or more tools):

- MCP: `enabled`, `timeout`/`startupTimeout`, `cwd`, `oauth`; remote
  transport `http`/`sse`.
- Agent: `color` validated against Claude's set, `mode`/`hidden`
  where opencode and Claude overlap, `temperature` if Codex has it.
- Command: `subtask`, `model`, `agent`.
- LSP: `initializationOptions`, `settings`, `disabled`, `startupTimeout`
  (opencode currently drops it).

Per target, an `extra` attrset merged last into frontmatter or JSON: Claude
agent `permissionMode`/`isolation`/`memory`/`background`, skill `arguments`/
`shell`/`license`, Codex `[agents]` and `[[skills.config]]`, opencode
`top_p`/`disable`.

### 5. Hooks (~1 day)

- Claude: replace freeform `settings.hooks` with a typed option: event enum
  (33), handler `type` (`command`/`http`/`mcp_tool`/`prompt`/`agent`),
  `matcher`, `if`, `async`, `timeout`. Also hooks in agent and skill
  frontmatter. Migrate `claude-code/git-push-guard` and the blind-choices
  addon.
- Codex: typed hooks (12 events, `command`/`mcp_tool`) rendered to
  `hooks.json`, or through upstream `programs.codex.hooks` if its schema fits.
- opencode: `plugins` option, name → JS source, written to
  `opencode/plugins/`.

### 6. Codex config (~half day)

- Switch to upstream `programs.codex.mutableSettings` after a parity check
  against `modules/home/programs/codex/tests.nix`; delete `mutableConfig` and
  `merge-program.nix`.
- Render non-default profiles to `$CODEX_HOME/<name>.config.toml`
  (`options.nix:145-155`).

### 7. Budget accuracy (~30 min)

Codex and opencode inline path-scoped rules into always-loaded context, but
`validation.nix:251-259` treats them as out of budget. Count them for those
targets.

## Open questions

- Is opencode's `reasoningEffort` agent key right, or should it be a provider
  option? Unverified in the audit.
- Codex `otel.metrics_exporter.otlp-grpc.endpoint` in the codex usage file:
  unverified.
- Claude LSP plugin under `plugins/lsp/` inside Claude's own `plugins/`
  directory: no docs on collisions.

## Risks

- All three tools ship weekly; field lists here go stale. Re-run the audit
  before each phase that touches a tool's schema.
- Phase 5 changes the shape of every existing Claude hook; a mistake disables
  the push guard silently. Its tests must cover the guard.

## Addendum 2026-10-20: Phases 1 and 7

- Phase 1 done. Phase 7 done.
- Docs re-checked: Claude `attribution.commit`/`.pr` (empty string hides),
  no agent `category` or skill `version` in the frontmatter tables (skill
  `metadata` is a free-form map); Codex rust-v0.163.0 `host_roots.rs` reads
  `~/.agents/skills` and keeps `$CODEX_HOME/skills` as deprecated; opencode
  loads `~/.config/opencode/plugins/`.
- The plan missed a second singular plugin path:
  `home/common/optional/development/ai/ai-proxy/default.nix` wrote
  `opencode/plugin/ai-proxy.js`. Moved to `plugins/` too.
- Codex skills no longer go through upstream `programs.codex.skills`, which
  hard-codes `$CODEX_HOME/skills`; the target writes `home.file` under
  `~/.agents/skills` itself.
- opencode also scans `~/.agents/skills` (before its own dir, last wins, with
  a "duplicate skill name" warning). Shared skills resolve to opencode's own
  copy, but the commands and agents Codex renders as skills now also show up
  in opencode as skills. Phase 3 removes the agents; commands remain until
  Codex skills move somewhere opencode does not read.
- opencode still emits skill `version` (`targets/opencode.nix`), which its
  frontmatter ignores. Left for Phase 2, which rewrites that frontmatter.
- Phase 7 adds a second always-on check for the default profile, counting
  path-scoped rules, run only when codex or opencode is enabled and the
  profile has a path-scoped rule. The Claude check is unchanged.

## Addendum 2026-10-20: Phase 2

- Phase 2 done.
- opencode 1.19.0's CLI ignores `metadata."opencode/slash"` and
  `"opencode/autoinvoke"`; only its unused v2 core (`packages/core`) reads
  them. The docs describe that core. The CLI already turns every skill into a
  `/name` command, so dropping the copies in `commands/` loses nothing. We
  emit both keys per the docs. Until the CLI reads `autoinvoke`, a manual-only
  skill also gets `permission.skill.<name> = "deny"`, which 1.19.0 does apply
  to `<available_skills>` (tagged `FLAKE-UPDATE`). A user-only skill still
  shows in the 1.19.0 slash menu.
- opencode skill frontmatter reads only `name`, `description`, `license`,
  `compatibility`, `metadata`. `version` stays under `metadata`, as Claude
  has it. The Claude hints (`context`, `model`, `agent`, `reasoningEffort`)
  are dropped.
- Codex rust-v0.163.0 `SKILL.md` reads only `name`, `description`, and
  `metadata.short-description`. Everything else is dropped. `invocation.user =
  false` has no Codex equivalent. `allow_implicit_invocation` defaults to
  true, so `agents/openai.yaml` is written only for manual-only skills. A
  `resourcesRoot` that already holds one fails the build.
- opencode permission keys (1.19.0 `ConfigPermissionV1`): `read`, `edit`,
  `glob`, `grep`, `list`, `bash`, `task`, `external_directory`, `todowrite`,
  `question`, `webfetch`, `websearch`, `lsp`, `doom_loop`, `skill`, plus
  `<server>_<tool>` for MCP. Claude's bare `mcp__server` maps to
  `server_*`. A wildcard `"*": "deny"` also denies `external_directory` and
  `doom_loop`, which Claude's allowlist does not cover.
- The `~/.agents/skills` overlap: opencode has no config key for it. The
  `OPENCODE_DISABLE_EXTERNAL_SKILLS` env var lost: it also drops project
  `.agents/skills` and `.claude/skills`, and setting it means wrapping the
  package outside this module. Chosen instead: when the Codex target is on,
  opencode denies, via `permission.skill`, the names Codex renders from
  commands and agents. Verified with `opencode debug skill`: opencode's own
  copy of a shared skill wins, since it is scanned last. The cost: one WARN
  log line, "duplicate skill name", per shared skill. Denied names still
  appear in `opencode debug skill` and the slash menu.
- `lib/frontmatter.nix` now quotes keys that are not plain identifiers. A
  bare `*:` key would parse as a YAML alias.

## Addendum 2026-10-20: Phase 3

- Phase 3 done.
- Codex rust-v0.163.0 (`agent-roles/src/loader.rs`) reads every `*.toml`
  under `<config layer>/agents`, recursively, so the user dir is
  `$CODEX_HOME/agents` (here `~/.config/codex/agents`), not `~/.agents`. The
  `name` field wins over the filename. Upstream `programs.codex` has no agents
  option; the target writes `home.file` itself.
- An agent file is a full `config.toml` layer, but the docs say
  `model_provider`, `sandbox_mode`, `approval_policy` and `mcp_servers` do not
  override the parent from there. A `provider/model` value can't be routed, so
  Codex drops it, along with Claude names (`inherit`, `sonnet`, `opus`,
  `haiku`, `fable`, `opusplan`, `claude-*`). Every agent in this repo uses a
  Claude alias, so none sends a model to Codex today.
- `tools`/`disallowedTools` stay unmapped. Codex can only switch off whole
  features (`features.shell_tool`, …). Its shell is also how it reads files,
  so mapping a Claude `Bash` deny would block reads too. `maxTurns`, `color`
  and `skills` have no Codex field.
- Codex's `ReasoningEffort` enum is `none`, `minimal`, `low`, `medium`,
  `high`, `xhigh`, `max`, `ultra`, `persistent`, plus custom strings. `ultra`
  joins the shared enum because the subagent docs list it as a level. `none`
  and `persistent` don't, because the docs never mention them. Claude drops
  `ultra`: ultracode is a setting, not an effort level. opencode passes it
  through, and whether its key is right is still an open question.
- opencode no longer denies agent names as skills. Command names stay denied.
- opencode agent permission maps now hold `external_directory` and
  `doom_loop` at their documented `ask` default under a `"*": "deny"`.
  Checked with `opencode debug agent`: both resolve to `ask`, and the
  unlisted tools stay denied.
- Checked with codex-cli 0.163.0 using a temp `CODEX_HOME` and an unreachable
  provider (`RUST_LOG=trace codex exec`). The spawn tool lists both rendered
  roles, with model and effort. A file missing `developer_instructions` gets
  "Ignoring malformed agent role definition".

## Addendum 2026-10-20: Phase 4

- Phase 4 done.
- Every shared entry (agent, skill, command, MCP, LSP) has `extra.<target>`,
  merged last with `recursiveUpdate`. LSP has no `codex` key, since Codex has
  no LSP. Codex skill and command extras go to `agents/openai.yaml`, which is
  where Codex reads per-skill settings. Its `SKILL.md` frontmatter holds only
  `name`, `description` and `metadata.short-description`.
- Shared MCP fields: `enabled`, `startupTimeout`, `toolTimeout`, `cwd`
  (local), `headersHelper` (remote), and `oauth.{clientId,callbackPort,scopes}`
  (remote). Timeouts are in milliseconds. The plan's single "timeout" was
  really two settings:
  - Claude's `timeout` is a per-tool-call limit, so it maps to Codex
    `tool_timeout_sec` (ms / 1000).
  - opencode's `timeout` covers connect plus tool listing (`mcp/index.ts`), so
    it maps to Codex `startup_timeout_ms`. Claude has no per-server startup
    timeout.
- Codex `http_headers_helper` (rust-v0.163.0 `mcp_types.rs`) has the same
  contract as Claude's `headersHelper`, so the helper is shared. opencode
  supports `oauth.callbackPort` too (1.19.0 `v1/config/mcp.ts`).
- A client secret is not typed. Codex and opencode both read one, but it
  would land in the world-readable store. Pass it through `extra` if you must.
- The remote transport type (`sse`/`ws`) is Claude-only, so it goes in
  `extra.claude-code.type`. opencode negotiates the transport itself, and
  Codex speaks only streamable HTTP. The same goes for Claude's
  `alwaysLoad`/`authServerMetadataUrl` and Codex's
  `required`/`enabled_tools`/`env_vars`/`bearer_token_env_var`/
  `env_http_headers`/`tools.<t>.approval_mode`.
- Claude Code has no per-entry `enabled`, so a disabled MCP or LSP server is
  left out of its files. The `enabledMcpjsonServers` lists would be the
  alternative, but they are settings and do not fit a per-entry option.
- Shared LSP fields: `enabled` and `initializationOptions`, which opencode
  calls `initialization`. LSP `command` and `extensionToLanguage` are now
  optional at the type level. An assertion still requires them while
  `enabled`, so a disabled entry with no command can switch off an opencode
  built-in. Claude's `settings`, `transport`, `workspaceFolder`, the timeouts
  other than `startupTimeout`, `restartOnCrash`, `maxRestarts` and
  `diagnostics` go in `extra`. Claude's `.lsp.json` is strict, so a typo
  there fails the plugin load.
- Agent `color` is an enum of Claude's eight names. opencode 1.19.0 rejects
  the whole config on any color that is neither `#rrggbb` nor a theme name
  (checked with `opencode debug agent`), so it gets a hex value per name.
  `mode`, `hidden`, `temperature` and `top_p` are opencode-only, and so is
  `disable`. Claude's `permissionMode`, `memory`, `background`, `isolation`,
  `initialPrompt`, `omitClaudeMd`, `autoCompactWindow`, `experimental`,
  `mcpServers` and `hooks` are Claude-only. All of them go in `extra`.
- Shared skill fields: `license`, `compatibility` (opencode still defaults
  to `opencode`) and `metadata`. Shared command fields: `model`, `agent` and
  `subtask` (Claude `context: fork`). opencode drops a bare model alias on a
  command, as it does on an agent.
- `lib/frontmatter.nix` used to render a list item whose first field was a
  map or list as inline JSON in a string. Hooks and agent `mcpServers` hit
  that, so it now renders nested YAML.
- The open question is settled: opencode's `reasoningEffort` key is right. In
  1.19.0, an unknown agent key moves into `options` (`v1/config/agent.ts`),
  which `session/llm/request.ts` merges into the provider options.
  `opencode debug agent` shows `options.reasoningEffort`. Only providers that
  read the key act on it.
- Codex `[agents]`, `[[skills.config]]` and `skills.max_context_tokens` are
  global settings, not per-entry ones. They are already reachable through
  `programs.codex.settings`, which merges with this target. Nothing writes
  `AGENTS.override.md`, since the target owns `AGENTS.md`.
- Left open: frontmatter keys the normalizer does not know are still dropped.
  For example, `memory: project` and `background: true` in the repo's agent
  files never reach Claude. Routing them into `extra.claude-code` needs typed
  values, and `lib/frontmatter.nix` parses every value as a string.
- Checked against the real tools in a temp HOME. `opencode debug config`
  accepted the rendered MCP, LSP, command and agent shapes. `codex mcp list`
  accepted the MCP keys, showing `startup_timeout_sec: 20.0` from
  `startup_timeout_ms`. `claude plugin validate` accepted `.lsp.json` with
  `initializationOptions`, plus `.mcp.json` with `headersHelper`, `oauth`,
  `timeout` and `type: sse`.

## Addendum 2026-10-20: Phase 5

- Phase 5 done.
- Docs re-checked, not the plan's counts. Claude Code has 33 events and 5
  handler types. Handler fields: `if`, `timeout`, `statusMessage`, `once`
  (skill frontmatter only), command `args`/`async`/`asyncRewake`/`shell`/
  `onFailure`, http `headers`/`allowedEnvVars`/`onFailure`, mcp_tool
  `server`/`tool`/`input`, prompt/agent `prompt`/`model`, and prompt
  `continueOnBlock`. Codex rust-v0.163.0 (`config/src/hook_config.rs`,
  `hooks/src/engine/discovery.rs`) has 12 events. `prompt` and `agent` parse
  but are skipped, so only `command` and `mcp_tool` are typed.
- Claude hooks stay at `settings.hooks`, because the top-level `hooks` option
  already names hook script files. `settings` is now a submodule with a JSON
  freeform type and a typed `hooks`. Existing users keep their syntax and are
  validated without edits: git-push-guard, blind-choices, design-notes,
  code-standards and spec-driven-dev. A test renders each one through the
  typed option and compares it with the same module evaluated freeform.
  Multi-source list merging is unchanged. Event names and field names are
  checked by the module system. Fields that belong to another handler type,
  missing required fields, `if` off tool events, `matcher` on events without
  matcher support, and `once` outside skills each fail an assertion.
- Agent and skill frontmatter hooks stay in `extra.claude-code.hooks`, per
  ADR 0005 option 3 and the Phase 4 addendum. A typed field would put a
  Claude-only key in the shared layer. They are still typed (ADR option 1):
  the Claude target runs them through the settings hook type, and
  validation.nix asserts the same checks.
- Codex: `targets.codex.hooks` is rendered into upstream
  `programs.codex.hooks`. Upstream's schema is freeform JSON written to
  `CODEX_HOME/hooks.json`, so it fits. The checks mirror discovery.rs:
  mcp_tool on SessionEnd is skipped, async on SessionEnd runs synchronously,
  SessionEnd/Interrupt timeouts clamp at 3 s, `additionalContextLimit` works
  only on events that emit context, and `input` cannot hold a null. A
  codex-cli 0.163.0 run in a temp `CODEX_HOME` ran the rendered SessionStart
  hook and warned "SessionEnd MCP hooks are not supported".
- opencode: `targets.opencode.plugins` maps a file name to text or a path, one
  `xdg.configFile` entry per file, so the ai-proxy and ollama-autodiscover
  files stay. `opencode debug config` lists `.js` and `.ts` plugins but
  ignores `.mjs` and files with no extension, so other names fail an
  assertion.
- Frontmatter keys the shared layer doesn't lift now go to `extra.claude-code`
  for agents, skills and commands, with an explicit `extra` winning.
  `lib/frontmatter.nix` gains `typedAttrs`: plain `true`/`false`/integers/
  `null`/`[a, b]` are typed, and quoted values stay strings. Rules keep
  dropping them, since rules have no `extra`. Gains today: `memory: project`
  on both `system-architect.md` and `spec-driven-dev/.../spec-reviewer.md`,
  and `background: true` on both `silent-failure-hunter.md`.
- `claude plugin validate` accepted a hooks.json using every handler type and
  field above, plus an agent with frontmatter hooks. It also confirmed that
  an unknown event is only a warning ("entry ignored at runtime"), which is
  why event names are typed.
- Left open: `lib/frontmatter.nix` drops empty lists, so `args = []` (exec
  form with no arguments) survives in settings.json but not in frontmatter
  hooks.

## Addendum 2026-10-20: Phase 6

- Phase 6 done.
- Parity check against home-manager `1a95e2ef` (`programs/codex` with
  `lib.hm.generators.mkImpureConfigMerger`). Every case in the old
  `modules/home/programs/codex/tests.nix` now runs against the upstream
  activation script, and all of them hold:

  | Case | Ours (`mutableConfig`) | Upstream (`mutableSettings`) |
  | --- | --- | --- |
  | Key conflicts | `$runtime * declared`, declared wins | `$dynamic * $static`, same |
  | Arrays | declared replaces | same |
  | Runtime subtable of a declared table | kept | kept |
  | Missing file | created | created, `{}` also for an empty file |
  | Invalid TOML | refuses, exit 1, file untouched | same, "Could not parse config" |
  | Mode | always forced to 600 | 600 when new, otherwise kept |
  | Store link at the target | replaced | refused, "resolves into the Nix store" |
  | Ordering | after `linkGeneration`, entry disabled | same |
  | Idempotent | yes | yes |

  Upstream also skips on `DRY_RUN`, refuses when the file changes mid-merge,
  writes in place on a bind mount, and removes an unchanged file when you
  switch back to immutable. It merges when MCP or plugin settings are set,
  not only `settings`. Neither difference loses data. The mode case only
  matters for a file we did not write, and ours are already 600. A store link
  can't reach the merge, since `linkGeneration` removes the stale one first.
  ADR 0005 option 7 stands, with no superseding note needed.
- `mutableConfig` and `merge-program.nix` are gone. The one user,
  `home/common/optional/development/ai/codex`, sets `mutableSettings`.
  `modules/home/programs/codex` now only extends `mutableSettings` to profile
  files, and its tests cover the upstream-backed configuration.
- Profiles: codex-cli 0.163.0 (`config/src/loader/mod.rs`, docs
  `config-file/config-advanced`) loads `$CODEX_HOME/<name>.config.toml` as a
  second user layer over `config.toml` when started with `--profile <name>`.
  `[profiles.<name>]` tables have been rejected since 0.134.0. A missing file
  is an empty layer. Names must match `[A-Za-z0-9_-]+`, which is now an
  assertion. Upstream `programs.codex.profiles` writes these files, so the
  target sets that option.
- Under `--profile`, Codex writes state into the profile file, not
  `config.toml` (`get_active_user_layer`, `ConfigManagerService::apply_edits`).
  This was checked with the real TUI. A store-linked `work.config.toml` gave
  "failed to persist config at …/work.config.toml". So with `mutableSettings`
  on, each profile file is merged the same way `config.toml` is
  (`modules/home/programs/codex/default.nix`).
- What a profile maps to: the file holds only the differences from the
  default profile. MCP servers whose rendered form changed go in as-is.
  Default servers the profile lacks get `enabled = false`. Instructions and
  rules the default doesn't have go in as `developer_instructions`, with the
  parent's instructions prefix stripped. Skills, agents, commands and hooks
  sit in global directories, so they stay the default profile's. A rule the
  profile drops, or rewrites under the same name, still loads from
  `AGENTS.md`. Shared profiles have no model or effort field. Set those
  directly in `programs.codex.profiles.<name>`, which merges with the target.
  `codex --profile ops mcp list` and `debug prompt-input` both confirmed the
  rendered shape.
- Launcher: `agent-run` picks no profile for any tool. Profiles go through
  after `--` (`agent-run --agent codex -- --profile ops`), and Codex and the
  Claude wrapper both take `--profile`. No change needed.
- The Phase 7 inlined budget now covers every profile when Codex is on.
  opencode still renders only the default.
- Found, not fixed: `resolve-profile.nix` merges `mcpServers` with
  `recursiveUpdate` over fully defaulted entries. A profile that overrides one
  field of an inherited server (`mcpServers.x.args = …`) resets `command` to
  null. That affects every target.

## Addendum 2026-10-21: quality refactor

Phases 1–7 met the feature goals but left the module structure wrong. Three
read-only reviews (code quality, contracts, silent failures) found the issues
below. The refactor runs in three ordered steps, R1–R3. Every step keeps the
module-test checks green and the test count at least as high. Moved tests
keep their names.

### Target structure

The rule that matters gets a test. Dependencies run one way only:
shared profile model → target → tool module. Nothing points back.

- The **shared profile model** (`code-assistant-profiles/`: types, resolve,
  validation, budgets, launcher, skill resources, content helpers) imports
  nothing from `targets/` or from `modules/home/programs/{claude-code,codex}`.
  A test in `tests.nix` reads the shared files and fails on any such import.
- **Each target** is a directory, `targets/<tool>/`. It owns its options
  (Codex `hooks`, opencode `plugins`), its tool-only types (hook schema), its
  validation (Claude frontmatter hooks), and its tests. The shared
  `options.nix` keeps only the `targets.<tool>.enable` toggles.
- **The Claude target becomes a module**, like the Codex and opencode targets.
  The shared `default.nix` imports it, and it sets
  `programs.claude-code-profiles.*`. `modules/home/programs/claude-code` no
  longer imports the shared target.
- **The Claude hook schema** stays with the Claude tool module
  (`modules/home/programs/claude-code/hooks.nix`), because it describes
  Claude's own settings file. The Claude target imports it, in the allowed
  direction.
- **The hook schema builder** goes in `lib/hook-schema.nix`, beside
  `lib/frontmatter.nix`. Claude and Codex both build on it, which justifies
  it. It takes `{events, handlerTypes, commonFields, typeFields,
  requiredFields, eventChecks}` and returns `{hooksType, render, problems}`.
- **No `common.nix` bucket.** Content helpers that every target uses
  (`readContent`, `hasInstructions`, inline rule rendering, skill description
  from `whenToUse`, `withExtraFor`) are shared-model operations. They go in a
  domain-named file such as `content.nix`. The skill dir derivation
  (`mkSkillDir`) goes in `skill-resources.nix`.

### R1: correctness

1. Merge, then type (contracts #1, #6). Profiles and baseConfig entries are
   merged raw, then typed once, so an override of one field keeps inherited
   fields (`command`, `enabled = false`, `prompt`, `description`). Regression
   test: a child that overrides only `args` keeps `command` and
   `enabled = false`. Cover agents, skills and LSP too.
2. Frontmatter values get the same checks as Nix values (contracts #2). A
   lifted `color` or `effort` outside its enum fails with a named assertion,
   not a missing-attribute error in opencode.
3. Lift frontmatter `metadata` into the typed field (contracts #3), so Codex
   and opencode get it.
4. `lib/frontmatter.nix` flow lists: throw on an unmatched quote, and keep a
   quoted comma inside its item (silent-failure, medium).
5. Codex profiles that render to `{}` produce a `warnings` entry naming them
   (silent-failure, medium).
6. Confirm `mkImpureConfigMerger` fails loudly on an unparsable profile file.
   Read the upstream source; if it doesn't fail loudly, add a guard
   (silent-failure, low).
7. Drop `or null` / `or {}` on typed options that have defaults, so a typo
   throws (silent-failure, low; code-quality #18).

### R2: structure

Apply the target structure above, plus:

- Code-quality #6–#12: hook schema builder; shared content helpers;
  `mkSkillDir`; Codex exposes the skill names it writes to
  `~/.agents/skills` (an internal option), and opencode reads that instead
  of re-deriving it; one `codexHomeRelative`; `resolve-profile` exposes a
  profile's own instructions so Codex stops splitting on `"\n\n"`; extra-key
  bookkeeping is derived, not a hand-kept `knownKeys` list.
- Contracts #4: LSP `startupTimeout` moves to `extra.claude-code`, since only
  Claude reads it. Migrate the `java` entry in
  `home/common/optional/development/ai/code-assistant-profiles/default.nix`.
- Contracts #5: LSP timeouts use `ints.positive`; `toolTimeout` is at
  least 1000 ms.
- Contracts #7: `extra` on rules; document that command `extra.codex`
  reaches the skill Codex generates for it.
- Contracts #8: option docs say Codex hooks and opencode plugins are global
  while Claude hooks are per profile.
- Contracts #9 and code-quality #13: one colour name→hex map, with the enum
  built from it; the effort list named once.
- Breaking change: `lib.mkRenamedOptionModule` from
  `programs.codex.mutableConfig.enable` to `programs.codex.mutableSettings`.

### R3: tests and cleanup

- Code-quality #5: split `code-assistant-profiles/tests.nix` into per-area
  files, one per target plus resolve, validation, budgets and launcher, with
  a small aggregating `tests.nix`.
- Code-quality #4: module tests stop importing `home/`. Push-guard tests move
  to `home/common/optional/development/ai/claude-code/git-push-guard/tests.nix`,
  which module-tests auto-discovers. Add regression tests for the
  2026-10-21 guard fixes: unreadable hook input asks; `ALLOW_GIT_PUSH=0`
  and `=false` are blocked; a non-push subcommand passes.
- Silent-failure, low: pair each negative `hasInfix … false` with a positive
  check on the same rendered value.
- Code-quality #14–#23: `nonEmptyList` everywhere; usage-section
  simplification; drop dead and test-only exports; named constants for magic
  numbers; option descriptions; one-line comments; heredoc indentation;
  frontmatter parsed once; redundant `codingCfg.enable` guards.

### Known limits, accepted

The push guard stops accidents, not someone deliberately working around it:
`/usr/bin/git`, `command git` with a changed PATH, or building the variable
name at runtime all get past it. This is intended (see the 2026-10-20
discussion that chose the shim).

### Guard fixes made directly, 2026-10-21

- `ask-on-override.sh`: unreadable input now asks. Before, a `jq` failure
  exited non-zero, and Claude treats that as a non-blocking error.
- `git-shim.sh`: only `ALLOW_GIT_PUSH=1` passes; `0` and `false` no longer
  do.

Both pass shellcheck and were exercised by hand. Their regression tests land
in R3.

### R1 done, 2026-10-21

- Merge, then type: `baseConfig`, `addons` and `profiles` declare their
  entries as `attrsOf anything` (`declaredProfileOptions` in `types.nix`);
  `instructions` stays typed. `resolve-profile.nix` merges them raw, with
  `prompt` and `content` replaced whole so a child's `text` never sits beside
  a parent's `source`, lifts frontmatter, and `resolved` types the result
  once. Validation now runs per resolved profile, so a `baseConfig` problem
  is reported under each profile's name rather than as `baseConfig`.
- Frontmatter checks: `validation.fieldTypeAssertions` checks every field of
  the merged, untyped profile against its option type and names the entry.
  A profile that fails it skips the typed checks, which would throw first.
  A non-numeric `maxTurns` stays a string so it reaches that check.
- Frontmatter `metadata` is lifted into the typed field; the Nix value wins
  per key.
- Flow lists split on commas outside quotes and throw on an unmatched quote.
- Codex warns for a profile whose overlay renders to `{}`.
- `mkImpureConfigMerger` already fails loudly on an unparsable file
  ("Could not parse config", exit 1). No guard added; a test now covers the
  profile file as well as `config.toml`.
- `or` fallbacks on typed fields dropped from the targets, validation and the
  launcher's skill list. The Codex command-to-skill shim now fills the skill
  fields it lacked.

Deviations and costs:

- A type error or typo in an entry now names the `resolved.<profile>` option
  and points at `code-assistant-profiles/default.nix`, not the user's file.
  An addon no profile includes is never typed.
- Two modules defining the same entry with different list values now
  conflict (`types.anything` merges lists only when equal) instead of
  concatenating. Nothing in `home/` does this today.
- No regression test for the dropped `or` fallbacks: a missing attribute is
  not catchable by `tryEval`, so the existing target tests cover them.

### R2 done, 2026-10-21

- Layout: `targets/{claude-code,codex,opencode}/` each own their module
  (`default.nix`) and options (`options.nix`, declared into the shared
  `targets` submodule). Codex keeps its hook schema in `targets/codex/hooks.nix`;
  the Claude target splits into `render.nix` (pure, profile to Claude shape) and
  `validation.nix` (frontmatter hooks). The shared `options.nix` keeps only the
  three `enable` toggles.
- The Claude target is a module imported by the shared `default.nix`. It sets
  `programs.claude-code-profiles.enable` (mkDefault) and a new internal
  `programs.claude-code-profiles.profileDefaults.<name>`, which the Claude tool
  module layers under each profile exactly where the old overlay sat. The tool
  module no longer reads `programs.code-assistant-profiles` at all, so it works
  without the shared module; with the shared module off, `profileDefaults` is
  `{}` and output is unchanged.
- One-way rule: `tests.nix` checks that no shared-model file (every `.nix`
  beside `default.nix` and `tests.nix`) mentions `targets/`, `../claude-code`
  or `../codex`, and that no file of the Claude or Codex tool module mentions
  `code-assistant-profiles`.
- `lib/hook-schema.nix` (`lib.custom.mkHookSchema`) builds the hook type,
  renderer and generic checks; Claude and Codex pass their events, fields and
  `eventChecks`. Shared content helpers are in `content.nix`; `mkSkillDir` is
  in `skill-resources.nix`; budgets moved out of `validation.nix` into
  `budgets.nix`.
- Codex exposes `targets.codex.writtenSkillNames`, which opencode subtracts
  from instead of re-deriving. `modules/home/programs/codex/codex-home.nix` is
  the one CODEX_HOME definition. `resolved.<name>.instructionSections` carries
  each layer's instructions, and Codex drops the default's sections instead of
  stripping a `"\n\n"` prefix. Frontmatter keys a field lifts are declared with
  that field (`derivedFields`), so the passthrough list is derived.
- Contracts: LSP `startupTimeout` is now `extra.claude-code.startupTimeout`
  (java migrated); MCP `toolTimeout` must be at least 1000; rules take
  `extra.claude-code`; option docs say Codex hooks and opencode plugins are
  global and Claude hooks per profile; one colour name→hex map and one effort
  list in `types.nix`; `programs.codex.mutableConfig.enable` is a renamed
  option for `mutableSettings`.
- Carried from R1: every `baseConfig` and addon entry is type-checked on its
  own, used or not. The check now walks into submodules, lists and attrsets and
  reports unknown fields, naming `addon '<name>'` or `baseConfig` and the field
  path.
- Proof: a scratch evaluation of all three targets plus the Claude tool module
  over a broad fixture set rendered the same home.file, xdg.configFile,
  programs.codex, programs.opencode, assertions and warnings before and after.
  Tests: 178 → 193 checks in code-assistant-profiles, 6 → 8 in codex, 21
  unchanged in claude-code.

Deviations:

- Claude skill directories with `resourcesRoot` are now built by the shared
  `mkSkillDir`, so their derivation is named `claude-code-skill-<name>` and its
  script is indented like the others. The output tree is byte-identical
  (`diff -r`), but the store path changes.
- A Codex profile with several parents now drops every default section, not
  just a leading prefix. Before, `extends = ["default" "ops"]` repeated the
  default's instructions in `developer_instructions`. Single-parent profiles,
  which is all `home/` has, render the same.
- Frontmatter-hook assertions run only when the Claude target is enabled,
  since they are Claude checks.
- A bad `baseConfig` entry is reported once as `baseConfig` and again under
  each profile.
- The builder takes `fields` (option declarations) and
  `typeFields`/`commonFields`/`requiredFields` (names), with `eventChecks =
  {group, handler}`; the plan's `handlerTypes` is the key set of `typeFields`.
- The colour enum is now alphabetical, so its error message lists the names in
  that order.
- `writtenSkillNames` is defined outside the Codex target's `mkIf`, because the
  condition reads `targets`, the option it lives in.
- Target tests stay in the shared `tests.nix` until R3. A `targets/<tool>/tests.nix`
  would collide with `module-test-claude-code` and `module-test-codex` in
  `checks/module-tests.nix`, so R3 needs other file names for them.

### R3 done, 2026-10-21

- Test layout: `code-assistant-profiles/tests.nix` now only aggregates
  `tests/{resolve,validation,budgets,structure,claude-code,codex,opencode,launcher}.nix`
  over shared `tests/fixtures.nix`. One directory, not `targets/<tool>/*-tests.nix`:
  `checks/module-tests.nix` discovers any file named `tests.nix`, so per-target
  files would need invented suffixes, and every area uses the same fixtures.
  Labels unchanged.
- Push-guard and addon hook-user tests moved to
  `home/common/optional/development/ai/claude-code/git-push-guard/tests.nix`
  (`module-test-git-push-guard`); module tests no longer read `home/`. The new
  shell checks run the built hook and shim: unreadable input asks; `ALLOW_GIT_PUSH`
  unset, empty, `0` and `false` are blocked with the rerun hint, as are
  `-C dir push` and `-c k=v push`; `stash push` passes; `ALLOW_GIT_PUSH=1`
  pushes to a local bare repo.
- Behaviour fixes, each with a regression test: `normalizeStringList "[]"` is
  `[]`, so `paths: []` no longer renders `- ''`; Codex hooks set while the Codex
  target is off are named in a warning; a bundled skill's SKILL.md is written with
  `cp` of a `writeText`, since the heredoc ended at a prompt line reading `EOF`.
- Cleanup: one `nonEmptyList` in the Claude render; the opencode usage section
  is one expression; dead exports (`alwaysOnMessages`, `assertExactlyOneTextSource`,
  `hasInstructions`) dropped; named constants (`listingWindowDivisor`,
  `minToolTimeoutMs`, `millisecondsPerSecond`, `shortEventTimeoutCeiling`);
  frontmatter parsed once per entity; redundant `codingCfg.enable` guards gone;
  comments cut to one line; `baseConfig` description no longer says "future adapters".
- Every negative `hasInfix … false` check is now `expectText` with text the
  same value must contain; the structure checks assert they read real files.
- Tests: code-assistant-profiles 193 → 201 expects (shell checks 43 → 45);
  claude-code 21 → 17 (4 moved); git-push-guard 0 → 4 plus 22 shell checks;
  codex 8 unchanged.

Left:

- Test-only exports (`measure*`, `resolveBudgets`, `selection*`,
  `includeCollisions`, `normalizeSharedConfig`, `resolveProfile`,
  `rejectReserved`) stay: rewriting 20-odd tests through `budgetMessages` would
  weaken where a failure points.
- Reviewer findings outside R3: an inherited `ALLOW_GIT_PUSH=1` passes the shim
  (candidate: `unsetEnv`); opencode plugins with the target off and target-ignored
  fields (`cwd`, `headersHelper`, timeouts) are not warned about; the frontmatter
  parser drops lines nested past one level.

### Test layout by path, 2026-10-21

Supersedes the R3 test-layout note above.

- `checks/module-tests.nix` names a check by the test file's directory from the
  repo root, `/` as `-`: `module-test-modules-home-programs-claude-code`,
  `module-test-home-common-optional-development-ai-claude-code-git-push-guard`.
  The root stays in the name because `modules/common` and `home/common` both
  exist. The duplicate-name throw stays: `a-b/c` and `a/b-c` still map to one
  name. Older names in this file (`module-test-claude-code`, `module-test-codex`,
  `module-test-git-push-guard`) are the pre-change ones.
- Each target's tests moved to `targets/{claude-code,codex,opencode}/tests.nix`,
  each its own check, labels unchanged. `code-assistant-profiles/tests.nix` keeps
  the shared-model areas in `tests/{resolve,validation,budgets,structure,launcher}.nix`.
- Shared helpers stay in `tests/fixtures.nix`; fixture data moved from
  `test-fixtures/` to `tests/fixtures/{clean,reserved}/`. The Claude render
  helpers (`claudeHooks`, `renderClaude`, `toClaude`) moved into the claude-code
  target's tests, so the shared fixtures import nothing from `targets/`.
- The structure check now also scans `tests.nix` and `tests/*.nix` (bar itself)
  for imports of targets or tool modules; target tests may import the shared
  fixtures.
- Assertion sites unchanged at 415 across all module-test checks;
  code-assistant-profiles 244 = shared 119 + claude-code 33 + codex 47 + opencode 45.

- 2026-10-21: the shared-model check moved from `code-assistant-profiles/tests.nix` to `code-assistant-profiles/tests/default.nix`; discovery treats a module's `tests/default.nix` as its suite, so the check is `module-test-modules-home-programs-code-assistant-profiles`.

### Render contract, 2026-10-21

- Every target is `targets/<tool>/render.nix`, a pure function from a resolved
  profile to that tool's artefacts, plus `default.nix`, which only writes them
  out, gates on `enable` and adds assertions and warnings. Each `render<Kind>`
  fills one attribute, in this order in all three:
  `{instructions, rules, agents, skills, commands, mcpServers, lspServers, hooks, dropped}`.
  Empty where the tool has no such concept, with a one-line reason: Codex and
  opencode `rules = {}` (inlined into `instructions`), Codex `lspServers = {}`,
  Claude `hooks = {}` (its hooks are per-profile settings). opencode `hooks` is
  its plugin files; Codex `hooks` is `targets.codex.hooks` rendered.
- Inputs a render needs arrive as arguments: Codex `skillsDir`, `hooks`,
  `codexHooks` and `base`; opencode `skillsDir`, `plugins` and
  `codexSkillNames`; Claude `claudeHooks`. Translation tables (Claude effort
  names, Codex's Claude-model pattern and metadata keys, opencode tool names,
  `reads`) sit at the top of each render.nix.
- `dropped` is `<kind>.<entry>` to the fields the entry sets away from its type
  default that the tool cannot express, from that render's `reads` table
  (`content.nix` `droppedFields`). `extra.<tool>` counts as a field. Values
  count too: a Claude model alias is dropped by Codex and opencode, `minimal`
  and `ultra` effort by Claude.
- `droppedFields` throws if a `reads` table names a field no entry type has,
  so a renamed field cannot silently stay "read".
- Warning rule: each enabled target publishes `dropped` per profile to the
  internal `droppedFields` option; the shared `default.nix` warns for a field
  every enabled target drops. A field one enabled target reads stays silent.
- Proof: a scratch evaluation of a broad fixture over all targets plus the
  Claude tool module, and of the real `home/.../code-assistant-profiles` with
  its addons, rendered the same home.file, xdg.configFile, programs.codex,
  programs.opencode, programs.claude-code-profiles and assertions before and
  after; the only difference is the new warnings. The real config gets one:
  `agents.deep-research-agent.category`, which no target reads.
- Tests: output-shape tests call render.nix through `typed`; module tests keep
  file paths, enable gating, assertions, warnings and the cross-target skill
  names. Labels kept; 210 → 229.

Deviations:

- The warning is built in the shared `default.nix`, not a target's, since the
  rule spans targets. Profiles with the same unread fields share one warning,
  not one each: profiles inherit entries, so per-profile warnings repeated the
  real config's one field five times.
- Codex renders a non-default profile through the same render with `base`, the
  default profile: it returns only MCP servers and instructions, the rest `{}`.
  `dropped` stays capability-based, the same for every profile, so opencode
  reports for profiles it does not write.
- Codex profile-overlay tests stay module-level: they need `extends` resolved.
- opencode `skills` is `{definitions, permission}`, since its hidden-skill list
  names Codex skills it does not define.

### Profile schema split and entry vocabulary, 2026-10-21

Supersedes the `types.nix` mentions above.

- `types.nix` is now `profile/`: `default.nix` holds the layering (the
  declared options of `baseConfig`, `addons` and `profiles`, the resolved
  profile, `profileType`, `resolvedProfileType`, and `entryTypes`, the one
  kind-to-schema map `content.nix` and `validation.nix` read);
  `agent.nix`, `skill.nix`, `command.nix`, `rule.nix`, `mcp-server.nix` and
  `lsp-server.nix` each hold one entry kind's schema; `fields.nix` holds what
  several kinds share (text source, reasoning effort, `extra`, colour names).
  `minToolTimeoutMs` stays in `mcp-server.nix`, its only user.
- Vocabulary: an **entry** is one skill, MCP server and so on; an **entry
  kind** is `skills`, `mcpServers` and so on. `sharedProfileOptions` is
  `profileContentOptions` ("shared" already means across tools here);
  `contentFields` is `entryKinds`, derived from `entryTypes`; validation's
  `entityKinds` is `entryLabels`; `entity` parameters and the
  `skillEntity`/`mcpEntity`/`lspEntity` test helpers say `entry`. One label
  changed: "every entity name is readable after resolution" is now "every
  entry name is readable after resolution". Option names unchanged.
- Colours: `profile/fields.nix` lists the names (`agentColors`, alphabetical,
  so the enum message is unchanged); opencode's hex map moved into
  `targets/opencode/render.nix`, keyed by those names, and a test renders every
  shared name through opencode and expects a hex value.
- The `profiles`, `addons`, `baseConfig` and entry-kind option descriptions
  point at the schema file each entry follows.
- Declared entry kinds keep merging raw but give option docs the entry's
  fields: the inner `attrsOf anything` borrows only `getSubOptions` from the
  entry type, so checking, merging and type error text are unchanged. A test
  lists the docs and expects fields of every kind; before the change the docs
  stopped at the kind.
- The structure check also reads `profile/*.nix` as shared-model files.
- Proof: the R2 scratch evaluation (broad fixtures over all targets plus the
  Claude tool module, and the real `home/.../code-assistant-profiles` with
  all targets enabled) is identical before and after: home.file,
  xdg.configFile, programs.codex, programs.opencode,
  programs.claude-code-profiles profileDefaults and resolved, assertions and
  warnings. The real config's only warning is still
  `agents.deep-research-agent.category`.
- Tests: expects 224 → 226 (opencode 48 → 49, resolve 38 → 39); all 20
  module-test checks build.

- 2026-10-21: `profile/` and the top-level `options.nix` merged into `options/`: `default.nix` (module options), `profile.nix` (declared vs resolved layering), `fields.nix`, and one file per entry kind. All of the module's options are now in one place. Supersedes the `profile/` paths above.

- 2026-10-21: the push-guard shim runs `programs.git.package` directly instead of finding git on PATH. Two shim builds on PATH (a claude started inside an older session's shell) handed an approved push back and forth forever; a marker-based skip could not fix shims already deployed. The regression test puts an old-style PATH-lookup shim on PATH in both orders.

- 2026-10-21: Claude's settings-file hooks are **settings hooks**, matching Claude Code's docs, which now keep "hook" for a mod's handler. `claude-code/hooks.nix` is `settings-hooks.nix`, imported as `claudeSettingsHooks`; the `hooks` option that writes scripts to a profile's `hooks/` is `hookScripts`, with `mkRenamedOptionModule` from `hooks` in `baseConfig`, `addons` and `profiles` (silent: submodules have no `warnings`). Unchanged: `settings.hooks` (settings.json's key), Codex hooks, `mkHookSchema`, opencode. Supersedes the `hooks.nix` and `claudeHooks` mentions above.

### Hack audit fixes, 2026-10-21

Each fix has a regression test that failed before it.

- Codex: every profile's agents, skills and commands go to the global dirs (Codex 0.163 has no per-profile agent or skill dir; `<name>.config.toml` only layers config). Two profiles defining one entry name differently fail an assertion naming both. `writtenSkillNames` is the union. Supersedes the render-contract deviation "returns only MCP servers and instructions, the rest `{}`" for what reaches `home.file`; the profile file itself is unchanged.
- Push guard: the hook matches `Bash|Monitor|PowerShell`, every Claude tool that runs a shell command. The shim skips `--attr-source <tree>` and resolves aliases through git's own config with the preceding `-c`/`-C`, blocking an alias that expands to `push` or a `!` alias naming push; an alias shadowing a git command passes, as git ignores it.
- `lib/frontmatter.nix` throws `frontmatter: <file>:<line>: <reason>` on YAML it cannot read (nesting past one level, lists of maps, continuation lines, flow maps, anchors, tags) instead of misreading it; reads CRLF, drops ` #` comments, unescapes `''` and `\"`. Tests in `lib/tests.nix` (check `lib-test-lib`). Every frontmatter `.md` under `home/`, `modules/` and `lib/` parses, bar an ADR template that is copied, never parsed.
- Models: `models.nix` `targetForModel` is the one classification (Claude aliases incl. `default`/`best`/`inherit` and `claude-*`, bare OpenAI ids, `provider/model`). Each target keeps only its own and reports the rest in `dropped`; Claude no longer passes `gpt-5` through. Supersedes "Codex's Claude-model pattern" in the render contract.
- claude-code: an assertion for a profile whose merged `memory` has both `text` and `source`.
- Tests: shared-model areas come from `readDir`; the one-way import check runs `nix-instantiate --parse` and reads path literals (with glued strings and interpolations) recursively, so comments and strings never count; a probe tree proves each rule fires. Each target's `validator.nix` is held to the render rule too.
- `validation.typeProblems` checks through `lib.evalModules` and walks only to name the failing field, so freeform submodules, `either`, `lazyAttrsOf` and every other type work. Messages unchanged.
- Manual-skill announcements are per profile through `profileDefaults` (not inherited, so a child lists its skills once), from `claude-code/manual-skills.nix`; the summary is the first sentence past abbreviations, or the whole description, or just the name.
- `codex-home.nix` has upstream's `isTomlConfig` again; a test compares it with upstream `programs.codex`'s `home.file` keys for both XDG settings and both config formats.
- `FLAKE-UPDATE` markers on the launcher flags and opencode's unknown-key behaviour; the launcher test greps each installed tool's `--help` for every flag word it passes.
- Scaffolding (`libWithCustom`, `hostStub`, `fakeClaude`) lives in `checks/module-test-support.nix`, imported through `self`; the dead `programs.code-assistant-profiles` stub is gone. The option-docs test already failed when entry docs go flat (checked by removing `getSubOptions`).

## Addendum 2026-10-21: assistant config checks

`assistant-config-<host>` runs each tool's own validator over the files that
host's home config writes, so a config a tool would reject fails
`nix flake check`. Run one with
`nix build .#checks.x86_64-linux.assistant-config-demon`. Why host configs are
evaluated inside checks: ADR 0006.

### Step 0: which validators run in the build sandbox

No network, `HOME` an empty temp dir, Claude Code 2.1.303, codex-cli 0.163.0,
opencode 1.19.0.

| Tool        | Validator                                        | Offline result                                                                                                                                                                                                                                                                                        |
| ----------- | ------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Claude Code | `claude plugin validate <dir>`                   | Works. On a profile dir it checks skills, agents and commands; on `plugins/lsp` and each `pluginDirs` entry, the manifest. Frontmatter YAML errors are only warnings.                                                                                                                                 |
| Claude Code | `claude doctor` with `CLAUDE_CONFIG_DIR`         | Works; reports `Invalid settings` with field paths, but exits 0, so the check greps the section. `plugin validate settings.json` treats it as a plugin manifest: unusable. The SchemaStore schema was not needed.                                                                                     |
| Codex       | `codex mcp list`, `codex --profile <p> mcp list` | Works; strict serde load of `config.toml` and the profile file (type errors fail). Accepts unknown enum strings and unknown profiles.                                                                                                                                                                 |
| Codex       | `codex doctor --json`                            | Exits 1 offline (auth, network), but its `config.load` row lists startup warnings, which include malformed `agents/*.toml`.                                                                                                                                                                           |
| Codex       | `hooks.json`                                     | Not read by any offline command, even when it is not JSON. Workaround: its `hooks` go into a scratch `config.toml` as `[hooks]` (same `HookEventsToml` type, `hook_config.rs`) and `mcp list` loads that; top-level keys checked against `HooksFile`'s `deny_unknown_fields`.                         |
| opencode    | `opencode debug config`, `debug skill`           | Works, but 71 s per call: the plugin-dependency npm install retries without network. `npm_config_fetch_retries=0` brings it to ~1 s; `OPENCODE_DISABLE_MODELS_FETCH`, `_DEFAULT_PLUGINS`, `_LSP_DOWNLOAD`, `_CLAUDE_CODE`, `_SHARE` set too. Validates `opencode.json` and `agents/*.md` frontmatter. |

### Design

- `modules/home/programs/assistant-config-check/check.nix`:
  `{pkgs, lib}: {name, homes}: derivation`, `homes` mapping user to evaluated
  home config. It takes the enabled `home.file` entries under each enabled
  tool's dirs (Claude profile dirs, `CODEX_HOME` and `~/.agents`,
  `$XDG_CONFIG_HOME/opencode`), links them into a fake `$HOME`, and runs the
  validators with the packages the host installs. Every failure is reported
  as `<host>: <tool>: <file>: \`<command>\` rejected it:` plus the tool's
  output; the output lists every validator run.
- `checks/assistant-configs.nix`: one check per NixOS, darwin or standalone
  home config of the current system with a user enabling any of the three
  tools. `programs.codex.mutableSettings` is forced off through
  `extendModules`, because under it `config.toml` reaches `$HOME` only at
  activation.
- Only the selected files are built, never `activationPackage`. Build time
  per host: demon 7.1 s, freya 5.8 s, zephy 5.9 s; evaluation adds about 20 s.
- `tests.nix` beside it: a clean fixture must pass and run every validator;
  seven fixtures must fail once each, naming tool, file and error: a plugin
  dir whose manifest lacks `name`, `permissions.defaultMode = "bogus"`, a
  command hook without `command`, a `hooks.json` with an extra key, a Codex
  profile with `mcp_servers = "none"`, an unparsable `agents/broken.toml`,
  and an opencode agent with `color: red`.
- Evaluation throws if an enabled tool selects no file, so a layout change
  cannot pass on an empty `$HOME`.

### Limits

- Claude `.mcp.json` and hook scripts are not validated: no offline command
  reads them without starting servers.
- `claude plugin validate` passes skills, agents and commands with only
  warnings (bad frontmatter YAML, no description); the check fails on errors
  only, since real hosts carry warnings (the LSP plugin has no `version`).
- `claude doctor`'s `Invalid settings` heading is matched as text; the
  settings fixture fails the test if Claude renames it, but only for the
  Claude version the module tests use (pkgs.claude-code, 2.1.301), not each
  host's.
- Codex accepts unknown enum values, and its profile files are checked only
  as far as `--profile <p> mcp list` loads them.
- What each tool ignores (unknown keys) still passes, and runtime failures
  (an MCP server that does not start) are out of reach.
- ghost evaluates only on aarch64-darwin: its home config already needs a
  darwin build during evaluation (obsidian-kanban-bases-view), as
  `darwin-ghost-evals` does.

- 2026-10-21: the validators live with their targets. Each `targets/<tool>/validator.nix` registers the tool's validator as `programs.code-assistant-profiles.validators.<tool>` (`option`, `enable`, `package`, `configDirs`, `extraDirs`, `setup`, `script`; schema in `options/validator.nix`), and `run-validators.nix` builds the fake `$HOME` and runs every enabled one, reading them from the host's home config rather than importing targets. `checks/assistant-configs.nix` only enumerates hosts. Each tool's bad-config fixtures moved to its `targets/<tool>/tests.nix`; the clean fixture is `tests/run-validators.nix`, which builds its home from `self.homeModules.default` so the shared tests import no tool module. `tests/default.nix` now takes every area file in `tests/`. Supersedes the `assistant-config-check/` paths above.
- 2026-10-21: Codex honours a profile's own entries per profile ("A: per profile"), superseding the "Codex: every profile's agents, skills and commands go to the global dirs" note above. The second profile's own `investigate` and `architecture-standards` failed demon, freya and zephy on it.
  - Skills and commands: a non-default profile's copy that differs from the default's goes to `~/.agents/skills/<name>--<profile>/`, its SKILL.md still `name: <name>`. `config.toml` disables every such copy by absolute SKILL.md path (`[[skills.config]]`); `<profile>.config.toml` disables the inherited copy and enables its own, both explicitly, since Codex applies the rules in layer order.
  - Agents: Codex 0.163 merges `[agents.<role>]` across config layers, the higher layer winning (`agent-roles/src/loader.rs`), so a profile file can repoint a role. A replaced role's default copy moves to `$CODEX_HOME/agent-variants/<name>.toml` and is declared in `config.toml`; the profile's copy is `agent-variants/<name>--<profile>.toml`, declared in its profile file. Both stay out of `agents/`: every user layer rescans that dir, and a declared role beside a scanned one of the same name is a "duplicate agent role" startup warning. `config_file` is relative, resolved against `CODEX_HOME`.
  - Remaining assertions: an entry the default lacks that two non-default profiles define differently (no default copy to replace, so the global slot that the default and every other profile read has two claimants; an entry only one profile defines stays global, as before), and a `<name>--<profile>` that another entry is already named.
  - Codex skips a symlinked SKILL.md (`local_file_system.rs` walk drops file symlinks; only directory links are followed), so every inline skill and every command was invisible to Codex. Each skill is now a linked directory (`mkSkillDir` takes a null `resourcesRoot`); tests read the built files.
  - Verified with codex-cli 0.163.0 on demon's rendered files (paths moved to a temp HOME): plain `codex` lists the personal `architecture-standards` and injects the personal `$investigate`; `--profile` with the second profile gets only that profile's copies of both; no duplicate-name warning. Agent roles checked the same way through a mock Responses server: `[agents.reviewer]` in the profile file swapped the role's description, other roles unchanged.

### Tests by kind, 2026-10-21

ADR 0007 is in place. Supersedes the `module-test-*`, `lib-test-*`, `assistant-config-<host>`, `tests.nix`, `tests/default.nix`, `checks/module-test-support.nix` and `import-rules.py` mentions above.

- Layout: `checks/discovery.nix` names every `tests/<kind>.nix` under `modules/`, `home/`, `lib/` and `checks/` as `<kind>:[home:|lib:|checks:]<area>[:<sub>]` (`unit:code-assistant-profiles:codex`, `script:home:ssh`, `unit:lib:frontmatter`); a stray `.nix` file or a `tests.nix` throws, and two tests with one name throw. `checks/tests/unit.nix` (`unit:checks`) tests those rules on an in-memory tree. Discovery reads the flake source, so a new test file must be tracked (`git add -N` is enough) before it runs.
- Unit suites run through nix-unit, negatives assert their message with `expectedError.msg`. A files test whose values need the flake (Home Manager, `self.homeModules`) checks them with `harness.values`, nix-unit-shaped cases run through `lib.runTests` at evaluation; rendered files are asserted with `harness.files` (by `home.file` name) and `harness.paths` (by store path): `exists`, `missing`, `content`, `contains`, `lacks`, `jq`, `toml`.
- Dependency rules (`unit:code-assistant-profiles:structure`) read option provenance: no shared-model file declares a target's option and a target declares only its own; only a tool's own target defines `programs.codex`, `programs.opencode` or `programs.claude-code-profiles`; each target registers only its own validator; no `render.nix` takes `config`; the claude-code module evaluates without code-assistant-profiles.
- Single-artefact validation moved into the derivation that builds it, behind `checkConfig` (default true): `programs.claude-code-profiles.checkConfig` runs `claude plugin validate` on the generated LSP plugin (in its manifest's build) and on every store path in `pluginDirs` (Prismantis included; the wrapper loads the checked copy); `programs.code-assistant-profiles.targets.codex.checkConfig` loads each agent role's TOML with `codex doctor --json`. `host:<host>` (`checks/hosts.nix`) keeps the whole-tree validators: profile-dir `plugin validate`, `claude doctor`, `codex mcp list`/`--profile`/`doctor`, `opencode debug config`/`skill`.
- `host:<host>` names come from the output kind (NixOS hosts under Linux systems, darwin hosts under darwin, every standalone home), never from evaluating a host: reading even a host's platform forced its module check, so one broken host failed every check. A host with no assistant user runs no validator; a standalone home of another platform writes a note pointing at its own system's check.
- `files:home:claude-code` renders the Prismantis settings and fails when they leave `pluginConfigs."prismantis@inline".options`.
- Test profiles and fixture strings use neutral names (`alt`, `other`).

### Hardening, 2026-10-21

- Whole-tree validators moved from `checks/hosts.nix` (deleted) into each home's build: `code-assistant-profiles` adds `run-validators.nix` to `home.checks` behind `programs.code-assistant-profiles.checkConfig` (ADR 0007 addendum). A home with no assistant adds nothing. Codex's `mutableSettings` is neutralised for the check through the validator's `staticConfig` and `extendModules`. A run where no validator ran fails. `checks/` imports nothing from the module (`unit:code-assistant-profiles:structure`). Supersedes the `host:<host>` notes above.
- `claude doctor` detection now runs a canary per claude: a known-bad settings.json must land under `Invalid settings`, so a reworded doctor fails the home's build on that claude, not only the module tests' version.
- Discovery throws on symlinks in tests dirs, a `tests` symlink, `.nix` files in tests subdirectories (subdirectories hold data only, `lib/tests/` included), and tests dirs with no suite; unit suites with no `test*` attribute fail. This surfaced `polyrepo/scripts/tests/`, a shell test that never ran: it now runs as `script:home:scripts`.
- A model no target routes gets its own warning naming profiles, entry and model. `checkConfig` with a null package throws for Codex agent roles and Claude plugin dirs. Codex reads `programs.codex.package` without a fallback. Every frontmatter `.md` under `home/`, `modules/`, `lib/` parses (`unit:lib:frontmatter-files`), the ADR template excepted.

- 2026-10-22: dropped the `programs.codex.mutableConfig.enable` rename alias and its two tests. Nothing in this repo or the ai-toolkit input set the old name, and nixpkgs traces the rename on every evaluation that does, so the alias test was the only source of that warning in `nix flake check`.
