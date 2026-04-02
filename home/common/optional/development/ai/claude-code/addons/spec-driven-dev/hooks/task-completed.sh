#!/usr/bin/env bash
# TaskCompleted hook: validate that completed tasks meet quality standards.
# Blocks completion (exit 2) if tests fail or acceptance criteria are not met.

INPUT=$(cat) || true
[ -n "$INPUT" ] || exit 0

TASK_SUBJECT=$(echo "$INPUT" | jq -r '.task_subject // empty') || true
TASK_DESC=$(echo "$INPUT" | jq -r '.task_description // empty') || true
CWD=$(echo "$INPUT" | jq -r '.cwd // empty') || true
CWD="${CWD:-${CLAUDE_PROJECT_DIR:-$(pwd)}}"

# Only validate spec-driven tasks (they have acceptance criteria in description)
if [ -z "$TASK_DESC" ] || ! echo "$TASK_DESC" | grep -q "Acceptance criteria" 2>/dev/null; then
	exit 0
fi

# Run build if a build command is detectable — capture output for diagnostics
if [ -f "$CWD/package.json" ]; then
	BUILD_OUT=$(cd "$CWD" && npm run build 2>&1) || {
		echo "Build failed. Fix before completing: $TASK_SUBJECT" >&2
		echo "$BUILD_OUT" >&2
		exit 2
	}
elif [ -f "$CWD/Cargo.toml" ]; then
	BUILD_OUT=$(cd "$CWD" && cargo build 2>&1) || {
		echo "Build failed. Fix before completing: $TASK_SUBJECT" >&2
		echo "$BUILD_OUT" >&2
		exit 2
	}
elif [ -f "$CWD/flake.nix" ]; then
	BUILD_OUT=$(cd "$CWD" && nix build 2>&1) || {
		echo "Build failed. Fix before completing: $TASK_SUBJECT" >&2
		echo "$BUILD_OUT" >&2
		exit 2
	}
fi

# Run tests if a test command is detectable
if [ -f "$CWD/package.json" ] && grep -q '"test"' "$CWD/package.json" 2>/dev/null; then
	TEST_OUT=$(cd "$CWD" && npm test 2>&1) || {
		echo "Tests failed. Fix before completing: $TASK_SUBJECT" >&2
		echo "$TEST_OUT" >&2
		exit 2
	}
elif [ -f "$CWD/Cargo.toml" ]; then
	TEST_OUT=$(cd "$CWD" && cargo test 2>&1) || {
		echo "Tests failed. Fix before completing: $TASK_SUBJECT" >&2
		echo "$TEST_OUT" >&2
		exit 2
	}
fi

# Check for TODOs/FIXMEs in recently modified files
CHANGED=$(git -C "$CWD" diff --name-only HEAD~1 2>/dev/null) || true
if [ -n "$CHANGED" ]; then
	TODOS=$(echo "$CHANGED" | xargs -d '\n' grep -n 'TODO\|FIXME\|HACK\|XXX' 2>/dev/null) || true
	if [ -n "$TODOS" ]; then
		echo "Found TODO/FIXME markers in changed files:" >&2
		echo "$TODOS" >&2
		exit 2
	fi
fi

exit 0
