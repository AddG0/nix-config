---
name: spec-steering-setup
description: "Create product.md, tech.md, and structure.md steering documents in .claude/steering/ by analyzing the project."
disable-model-invocation: true
allowed-tools: [Read, Glob, Grep, Bash, Write]
---

# Steering Setup

Create the `.claude/steering/` directory with three context documents that guide all spec-driven work.

## Step 1: Check Existing Files

Check if `.claude/steering/` exists. If any of the three files exist, ask the user whether to overwrite or keep each one.

## Step 2: Analyze the Project

Gather information automatically:
- Read `README.md` for product context
- Read config files: `package.json`, `Cargo.toml`, `go.mod`, `pyproject.toml`, `flake.nix`, `Makefile` (whichever exist)
- Scan directory structure (top-level and key subdirectories)
- Read `CLAUDE.md` or `.claude/` configuration if present
- Recent activity: !`git log --oneline -20 2>/dev/null || echo "no git history"`

## Step 3: Create Documents

Use the templates in `${CLAUDE_SKILL_DIR}/templates/` as starting points. Read each template, fill in the detected values, and write to `.claude/steering/`.

- `product.md` — Product context, users, value proposition, workflows
- `tech.md` — Stack, architecture, build/test commands, conventions, dependencies
- `structure.md` — Directory layout, entry points, module boundaries, naming conventions

## Step 4: Present for Review

Show all three documents to the user. Ask if anything needs correction or addition.

## Step 5: Report

```markdown
## Steering Setup Complete

Created:
- `.claude/steering/product.md` — Product context and workflows
- `.claude/steering/tech.md` — Stack, build, and conventions
- `.claude/steering/structure.md` — Layout and module boundaries

These provide context for all spec-driven workflows.
Review and refine them as the project evolves.
```
