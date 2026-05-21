#!/usr/bin/env bash
# Pre-build devShells of one or more flake repos so they land in the nix store.
# Recursively searches each target dir for flake.nix files (pruning common junk).
# Usage:
#   warm-flake-cache                  # recurse from PWD
#   warm-flake-cache ~/code ~/work    # recurse from each given dir
set -euo pipefail

# Bail out immediately on Ctrl+C instead of letting the loop chew through more repos.
trap 'printf "\n%s\n" "warm-flake-cache: interrupted" >&2; exit 130' INT TERM

# ── colors (only if stdout is a tty) ────────────────────────────────────────
if [ -t 1 ]; then
	C_RESET=$'\e[0m'
	C_DIM=$'\e[2m'
	C_BOLD=$'\e[1m'
	C_GREEN=$'\e[32m'
	C_RED=$'\e[31m'
	C_YELLOW=$'\e[33m'
	C_BLUE=$'\e[34m'
else
	C_RESET=""
	C_DIM=""
	C_BOLD=""
	C_GREEN=""
	C_RED=""
	C_YELLOW=""
	C_BLUE=""
fi

# Lines we filter from nix-fast-build's output — pure noise.
# Strips: SQLite contention warnings, unknown-setting warnings, and all of
# nix-fast-build's own INFO chatter (we already show progress per-repo).
NOISE_PATTERN='error \(ignored\): SQLite database .* is busy|warning: unknown setting|^INFO:nix_fast_build:'

fmt_duration() {
	local s=$1
	if [ "$s" -lt 60 ]; then
		printf "%ds" "$s"
	elif [ "$s" -lt 3600 ]; then
		printf "%dm%02ds" $((s / 60)) $((s % 60))
	else
		printf "%dh%02dm%02ds" $((s / 3600)) $(((s % 3600) / 60)) $((s % 60))
	fi
}

# Show path relative to $HOME (~/foo) if possible, else absolute.
short_path() {
	local p=$1
	if [[ $p == "$HOME"/* ]]; then
		# shellcheck disable=SC2088 # the tilde is intentionally literal for display
		echo "~/${p#"$HOME"/}"
	else
		echo "$p"
	fi
}

SYSTEM=$(nix eval --impure --raw --expr builtins.currentSystem)

targets=("$@")
if [ ${#targets[@]} -eq 0 ]; then
	targets=(".")
fi

# Dirs we never want to descend into while looking for flakes.
prune_names=(
	.git
	node_modules
	.direnv
	result
	.cache
	target
	build
	dist
	.venv
	venv
	__pycache__
	.next
	.nuxt
)

prune_expr=(\()
for i in "${!prune_names[@]}"; do
	if [ "$i" -gt 0 ]; then
		prune_expr+=(-o)
	fi
	prune_expr+=(-name "${prune_names[$i]}")
done
prune_expr+=(\) -prune)

printf "%s%s%s scanning for flake.nix...\n" "$C_DIM" "::" "$C_RESET"

repos=()
seen=""
for target in "${targets[@]}"; do
	if [ ! -d "$target" ]; then
		printf "%swarn:%s skipping '%s' (not a directory)\n" "$C_YELLOW" "$C_RESET" "$target" >&2
		continue
	fi
	while IFS= read -r -d '' flake; do
		repo=$(dirname "$flake")
		repo=$(realpath "$repo")
		case ":$seen:" in
		*":$repo:"*) continue ;;
		esac
		seen="$seen:$repo"
		repos+=("$repo")
	done < <(find "$target" "${prune_expr[@]}" -o -type f -name flake.nix -print0)
done

if [ ${#repos[@]} -eq 0 ]; then
	printf "%swarm-flake-cache:%s nothing to build\n" "$C_YELLOW" "$C_RESET" >&2
	exit 1
fi

total=${#repos[@]}
width=${#total}
overall_start=$SECONDS

printf "%s::%s building %sdevShells.%s%s for %s%d%s repo(s)\n\n" \
	"$C_BLUE" "$C_RESET" \
	"$C_BOLD" "$SYSTEM" "$C_RESET" \
	"$C_BOLD" "$total" "$C_RESET"

failed=()
i=0
for repo in "${repos[@]}"; do
	i=$((i + 1))
	short=$(short_path "$repo")
	printf "%s[%*d/%d]%s %s%s%s\n" \
		"$C_DIM" "$width" "$i" "$total" "$C_RESET" \
		"$C_BOLD" "$short" "$C_RESET"

	start=$SECONDS
	set +e
	# Run inside the repo dir (devenv-based flakes need PWD = repo root to
	# resolve their .devenv state) and with --impure (devenv reads
	# builtins.getEnv and the working directory during evaluation). Subshell
	# keeps the outer script's PWD unchanged. Relative ".#..." flake ref
	# because we've cd'd in. Filter known noise; preserve nix-fast-build's
	# exit code via PIPESTATUS.
	(
		cd "$repo" && nix-fast-build \
			--flake ".#devShells.$SYSTEM" \
			--skip-cached \
			--no-link \
			--no-nom \
			--impure
	) 2>&1 |
		grep --line-buffered -vE "$NOISE_PATTERN" |
		sed "s/^/  /"
	rc=${PIPESTATUS[0]}
	set -e
	dur=$((SECONDS - start))

	if [ "$rc" -eq 130 ] || [ "$rc" -eq 143 ]; then
		printf "  %s✗ interrupted%s after %s\n" "$C_RED" "$C_RESET" "$(fmt_duration "$dur")" >&2
		exit "$rc"
	fi
	if [ "$rc" -eq 0 ]; then
		printf "  %s✓ ok%s %s(%s)%s\n\n" \
			"$C_GREEN" "$C_RESET" "$C_DIM" "$(fmt_duration "$dur")" "$C_RESET"
	else
		failed+=("$repo")
		printf "  %s✗ FAIL%s %s(%s, exit %d)%s\n\n" \
			"$C_RED" "$C_RESET" "$C_DIM" "$(fmt_duration "$dur")" "$rc" "$C_RESET"
	fi
done

overall=$((SECONDS - overall_start))
ok=$((total - ${#failed[@]}))

printf "%s──── summary ────%s\n" "$C_DIM" "$C_RESET"
printf "  %s✓%s %d ok    %s✗%s %d failed    %selapsed%s %s\n" \
	"$C_GREEN" "$C_RESET" "$ok" \
	"$C_RED" "$C_RESET" "${#failed[@]}" \
	"$C_DIM" "$C_RESET" "$(fmt_duration "$overall")"

if [ ${#failed[@]} -gt 0 ]; then
	printf "\n  %sfailed repos:%s\n" "$C_RED" "$C_RESET"
	for repo in "${failed[@]}"; do
		printf "    - %s\n" "$(short_path "$repo")"
	done
	exit 1
fi
