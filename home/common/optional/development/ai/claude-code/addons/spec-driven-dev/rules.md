Spec-driven development workflow:

- Specs before code — for non-trivial features, create a spec in `.claude/specs/{feature}/` before implementing. Suggest `/spec-create` or `/interview` if asked to build something complex without a spec.
- One task at a time — execute tasks sequentially. Complete and validate one before starting the next.
- Human approval gates — pause for user confirmation after requirements validation, after design validation, after task validation, and after each task completion.
- Validation is mandatory — every completed task should pass the task-completion-validator.
- Steering context — read `.claude/steering/` files before starting spec work if they exist.
- Task dependencies — never skip dependency tasks. If Task 3 depends on Task 2, Task 2 must be complete first.
- TDD when implementing — use the RED-GREEN-BLUE cycle. Test-writer agents never see implementation. Implementer agents never modify tests.
- No shortcuts — no stubs, TODOs, placeholder code, hardcoded values, or swallowed errors in completed work.
