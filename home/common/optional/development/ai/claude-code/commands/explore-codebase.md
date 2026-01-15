---
description: Get familiar with a codebase using 4 parallel haiku agents for rapid exploration
allowed-tools: ["Task", "TaskOutput", "Read", "Glob", "Grep"]
---

# Explore Codebase

Rapidly understand an unfamiliar codebase by launching 4 haiku agents in parallel, each exploring a different dimension of the project.

## Why This Works

- **Parallel exploration** covers more ground faster than sequential reading
- **Specialized focus** per agent prevents information overload
- **Haiku model** is fast and cost-effective for exploration tasks
- **Synthesis step** combines findings into actionable understanding

## Workflow

**IMPORTANT:** Launch all 4 agents in a **single message** with multiple Task tool calls. Do NOT launch them sequentially.

### Step 1: Launch All 4 Agents in Parallel

Use the Task tool with these exact parameters for each agent:
- `model: "haiku"`
- `subagent_type: "Explore"`
- `run_in_background: true`

---

**Agent 1: Project Foundation**

```
prompt: |
  Explore the project foundation and entry points:

  1. IDENTIFY PROJECT TYPE
     - Language(s) and framework(s) used
     - Build system (package.json, Cargo.toml, go.mod, etc.)
     - Key dependencies and their purposes

  2. MAP DIRECTORY STRUCTURE
     - Top-level directories and their purposes
     - Where source code lives vs config vs tests
     - Any monorepo/workspace structure

  3. FIND ENTRY POINTS
     - Main application entry (main.ts, index.js, main.go, etc.)
     - CLI entry points if applicable
     - Server/API bootstrap files

  Output a concise summary with file paths for each finding.
```

---

**Agent 2: Architecture & Patterns**

```
prompt: |
  Analyze core architecture and design patterns:

  1. ARCHITECTURAL STYLE
     - Overall pattern (MVC, Clean Architecture, Hexagonal, etc.)
     - Layer separation (how is code organized?)
     - Module/package boundaries

  2. KEY ABSTRACTIONS
     - Important interfaces/traits/protocols
     - Base classes or mixins
     - Shared types and models

  3. DEPENDENCY PATTERNS
     - How dependencies are injected/managed
     - Service locator, DI container, or manual wiring
     - Configuration management approach

  Output findings with specific file paths and code references.
```

---

**Agent 3: Data & Integration**

```
prompt: |
  Trace data flow and external integrations:

  1. API SURFACE
     - REST/GraphQL/gRPC endpoints
     - Public interfaces exposed to consumers
     - Request/response handling patterns

  2. DATA LAYER
     - Database type and ORM/driver used
     - Schema definitions or migrations location
     - Data models and entities

  3. EXTERNAL SERVICES
     - Third-party API integrations
     - Message queues, caches, storage
     - Authentication/authorization services

  Output specific file paths and key function/class names.
```

---

**Agent 4: Development Workflow**

```
prompt: |
  Examine development and testing infrastructure:

  1. TEST SETUP
     - Test framework(s) in use
     - Test file locations and naming conventions
     - Types of tests (unit, integration, e2e)

  2. CI/CD
     - Pipeline configuration files
     - Build and deployment steps
     - Environment configurations

  3. DEVELOPER TOOLING
     - Linters, formatters, type checkers
     - Pre-commit hooks or git workflows
     - Local development scripts (dev server, watch mode)

  Output specific config files and key scripts.
```

---

### Step 2: Collect Results

Use `TaskOutput` to retrieve results from all 4 agents. Wait for all to complete.

### Step 3: Synthesize Findings

Combine all agent outputs into this format:

```markdown
# Codebase Overview: [Project Name]

## Quick Facts
- **Language/Framework:** [e.g., TypeScript + Next.js]
- **Architecture:** [e.g., Feature-based modular architecture]
- **Build System:** [e.g., pnpm + turbo]
- **Test Framework:** [e.g., Vitest + Playwright]

## Directory Map
[Tree-style overview of key directories]

## Entry Points
| Purpose | File |
|---------|------|
| Main app | `src/index.ts` |
| API routes | `src/api/` |
| CLI | `bin/cli.ts` |

## Key Abstractions
- **[Name]** (`path/to/file.ts`) - [one-line purpose]
- ...

## Data Flow
[Brief description of how data moves: API → Service → Repository → DB]

## Development Commands
| Task | Command |
|------|---------|
| Dev server | `pnpm dev` |
| Run tests | `pnpm test` |
| Build | `pnpm build` |

## Recommended Reading Order
1. `[file]` - [why read first]
2. `[file]` - [what you'll learn]
3. `[file]` - [key abstraction]
4. `[file]` - [example usage]
5. `[file]` - [integration point]
```

## Notes

- If any agent fails or times out, report partial results
- For very large codebases, agents may focus on most important areas
- Results are exploration-based, not exhaustive documentation
