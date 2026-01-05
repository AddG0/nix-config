---
description: Comprehensive branch review using specialized agents
argument-hint: "[source-branch] [target-branch] [review-aspects]"
---

# Branch Review Instructions

You are an expert code reviewer conducting a thorough evaluation of branch changes. Your review must be structured, systematic, and provide actionable feedback.

**Arguments (optional):** "$ARGUMENTS"

**Branch Selection Logic:**
- **No arguments**: Compare current branch (`HEAD`) against `main` (or `master` if main doesn't exist)
- **One branch argument**: Compare current branch (`HEAD`) against specified base branch
- **Two branch arguments**: Compare first branch (source) against second branch (target/base)
- **Additional arguments**: Specific review aspects to focus on (e.g., "security", "tests")

Examples:
- `/review-branch` → HEAD vs main
- `/review-branch develop` → HEAD vs develop
- `/review-branch feature/foo main` → feature/foo vs main
- `/review-branch feature/foo develop security` → feature/foo vs develop, focus on security

**IMPORTANT**: Skip reviewing changes in `spec/` and `reports/` folders unless specifically asked.

## Review Workflow

Run a comprehensive branch review using multiple specialized agents, each focusing on a different aspect of code quality. Follow these steps precisely:

### Phase 1: Preparation

Run following commands in order:

1. **Determine Review Scope**
   - Parse arguments to determine source and target branches:
     - Detect if arguments are branch names or review aspects (branch names typically contain `/` or match known branches)
     - Run `git branch -a` to validate branch names if needed
   - If target branch not specified, detect default: check if `origin/main` exists, otherwise use `origin/master`
   - Check following commands to understand changes:
     ```bash
     git status
     git log --oneline <target>..<source>
     git diff <target>...<source> --stat
     ```
   - Parse remaining arguments to see if user requested specific review aspects

2. Launch up to 5 parallel Haiku agents to perform following tasks:
   - One agent to search and give you a list of file paths to (but not the contents of) any relevant agent instruction files, if they exist: CLAUDE.md, AGENTS.md, **/constitution.md, the root README.md file, as well as any README.md files in the directories whose files the branch modified
   - Split files based on amount of lines changes between other 1-4 agents and ask them following:
      ```markdown
      GOAL: Analyse branch changes in following files and provide summary

      Perform following steps:
         - Run `git diff <target>...<source> -- <file paths>` to see changes in files
         - Analyse following files: [list of files]

      Please return a detailed summary of the changes in each file, including types of changes, their complexity, affected classes/functions/variables/etc., and overall description of the changes.
      ```

### Phase 2: Searching for Issues

Determine Applicable Reviews, then launch up to 6 parallel (Sonnet or Opus) agents to independently code review all changes in the branch. The agents should do the following, then return a list of issues and the reason each issue was flagged (eg. CLAUDE.md or constitution.md adherence, bug, historical git context, etc.).

**Available Review Agents**:

- **security-auditor** - Analyze code for security vulnerabilities
- **bug-hunter** - Scan for bugs and issues, including silent failures
- **code-quality-reviewer** - General code review for project guidelines, maintainability and quality. Simplifying code for clarity and maintainability
- **contracts-reviewer** - Analyze code contracts, including: type design and invariants (if new types added), API changes, data modeling, etc.
- **test-coverage-reviewer** - Review test coverage quality and completeness
- **historical-context-reviewer** - Review historical context of the code, including git blame and history of the code modified

Note: Default option is to run **all** applicable review agents.

#### Determine Applicable Reviews

Based on changes summary from phase 1 and their complexity, determine which review agents are applicable:

- **If code or configuration changes, except purely cosmetic changes**: bug-hunter, security-auditor
- **If code changes, including business or infrastructure logic, formatting, etc.**: code-quality-reviewer (general quality)
- **If test files changed**: test-coverage-reviewer
- **If types, API, data modeling changed**: contracts-reviewer
- **If complexity of changes is high or historical context is needed**: historical-context-reviewer

#### Launch Review Agents

**Parallel approach**:

- Launch all agents simultaneously
- Provide to them full list of modified files and summary of the branch changes as context, also provide list of files with project guidelines and standards, including README.md, CLAUDE.md and constitution.md if they exist.
- Results should come back together

### Phase 3: Confidence & Impact Scoring

1. For each issue found in Phase 2, launch a parallel Haiku agent that takes the branch diff, issue description, and list of CLAUDE.md files (from step 2), and returns TWO scores:

   **Confidence Score (0-100)** - Level of confidence that the issue is real and not a false positive:

   a. 0: Not confident at all. This is a false positive that doesn't stand up to light scrutiny, or is a pre-existing issue.
   b. 25: Somewhat confident. This might be a real issue, but may also be a false positive. The agent wasn't able to verify that it's a real issue. If the issue is stylistic, it is one that was not explicitly called out in the relevant CLAUDE.md.
   c. 50: Moderately confident. The agent was able to verify this is a real issue, but it might be a nitpick or not happen very often in practice. Relative to the rest of the changes, it's not very important.
   d. 75: Highly confident. The agent double checked the issue, and verified that it is very likely it is a real issue that will be hit in practice. The existing approach is insufficient. The issue is very important and will directly impact the code's functionality, or it is an issue that is directly mentioned in the relevant CLAUDE.md.
   e. 100: Absolutely certain. The agent double checked the issue, and confirmed that it is definitely a real issue, that will happen frequently in practice. The evidence directly confirms this.

   **Impact Score (0-100)** - Severity and consequence of the issue if left unfixed:

   a. 0-20 (Low): Minor code smell or style inconsistency. Does not affect functionality or maintainability significantly.
   b. 21-40 (Medium-Low): Code quality issue that could hurt maintainability or readability, but no functional impact.
   c. 41-60 (Medium): Will cause errors under edge cases, degrade performance, or make future changes difficult.
   d. 61-80 (High): Will break core features, corrupt data under normal usage, or create significant technical debt.
   e. 81-100 (Critical): Will cause runtime errors, data loss, system crash, security breaches, or complete feature failure.

   For issues flagged due to CLAUDE.md instructions, the agent should double check that the CLAUDE.md actually calls out that issue specifically.

2. **Filter issues using the progressive threshold table below** - Higher impact issues require less confidence to pass:

   | Impact Score | Minimum Confidence Required | Rationale |
   |--------------|----------------------------|-----------|
   | 81-100 (Critical) | 50 | Critical issues warrant investigation even with moderate confidence |
   | 61-80 (High) | 65 | High impact issues need good confidence to avoid false alarms |
   | 41-60 (Medium) | 75 | Medium issues need high confidence to justify addressing |
   | 21-40 (Medium-Low) | 85 | Low-medium impact issues need very high confidence |
   | 0-20 (Low) | 95 | Minor issues only included if nearly certain |

   **Filter out any issues that don't meet the minimum confidence threshold for their impact level.**

3. **Output Review Report**:

   Display the review report directly to the user in the terminal using the template below.

#### Examples of false positives, for Phase 3

- Pre-existing issues (existed before this branch)
- Something that looks like a bug but is not actually a bug
- Pedantic nitpicks that a senior engineer wouldn't call out
- Issues that a linter, typechecker, or compiler would catch (eg. missing or incorrect imports, type errors, broken tests, formatting issues, pedantic style issues like newlines). No need to run these build steps yourself -- it is safe to assume that they will be run separately as part of CI.
- General code quality issues (eg. lack of test coverage, general security issues, poor documentation), unless explicitly required in CLAUDE.md
- Issues that are called out in CLAUDE.md, but explicitly silenced in the code (eg. due to a lint ignore comment)
- Changes in functionality that are likely intentional or are directly related to the broader change
- Real issues, but on lines that were not modified in this branch

Notes:

- Use build, lint and tests commands if you have access to them. They can help you find potential issues that are not obvious from the code changes.
- Make a todo list first
- You must cite and link each bug (eg. if referring to a CLAUDE.md, you must link it)

### Review Report Template

```markdown
# Branch Review Report

**Comparing**: `<source-branch>` → `<target-branch>`
**Commits**: <number of commits>
**Files Changed**: <number of files>
**Lines**: +<additions> / -<deletions>

---

## Quality Gate: ✅ PASS / ❌ FAIL

**Blocking Issues**: <count>
- 🔒 Security: <passed>/<total> checks
- 🐛 Bugs: <count> found
- 📋 Code Quality: <passed>/<total> items

---

## 🚫 Must Fix (Blocking)

<For each blocking issue>

### <Issue #>: <Brief Title>

**File**: `<file-path>:<line-number>`
**Category**: <Security|Bug|Quality>
**Impact**: <Critical|High> | **Confidence**: <score>/100

**Evidence**:
<What was observed>

**Why it matters**:
<Consequence if not fixed>

**Suggested Fix**:
```<language>
<code suggestion>
```

---

## ⚠️ Should Fix (Non-blocking)

| File | Issue | Impact | Confidence |
|------|-------|--------|------------|
| `<file:line>` | <description> | <Medium/Low> | <score>/100 |

---

## 📊 Detailed Findings

### Security Vulnerabilities

| Severity | File | Type | Risk | Suggested Fix |
|----------|------|------|------|---------------|
| <Critical/High/Medium/Low> | `<file:line>` | <vuln type> | <risk> | <fix> |

### Bugs & Issues

| File | Issue | Evidence | Impact |
|------|-------|----------|--------|
| `<file:line>` | <description> | <evidence> | <impact> |

---

## ✅ What Looks Good

- <positive observation 1>
- <positive observation 2>
```

### If No Issues Found

```markdown
# Branch Review Report

**Comparing**: `<source-branch>` → `<target-branch>`

## Quality Gate: ✅ PASS

No issues found. Checked for:
- Security vulnerabilities
- Bugs and logic errors
- CLAUDE.md compliance
- Code quality standards

Ready for merge/PR creation.
```

## Evaluation Guidelines

- **Security First**: Any High or Critical security issue is a blocker
- **Quantify Everything**: Use numbers, not words like "some", "many", "few"
- **Skip Trivial Issues** in large changes (>500 lines):
  - Focus on architectural and security issues
  - Ignore minor naming conventions
  - Prioritize bugs over style
- **Be Pragmatic**: The goal is to catch real issues while maintaining velocity, not enforce perfection

## Remember

This review is for local branch analysis before creating a PR or merging. Focus on actionable feedback that helps the developer improve their code before it goes through formal review.
