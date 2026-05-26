#!/usr/bin/env bash
# Clone every project in a GitLab group (recursive, includes subgroups) into
# ghq's managed layout under $(ghq root).

set -euo pipefail

usage() {
	cat <<'EOF'
Usage: ghq-gitlab-group [-u] [-j N] [--include-archived] <group-path>

Clones every project in a GitLab group (and its subgroups) via ghq.

Arguments:
  <group-path>    Full GitLab group path, e.g. my-org/some-subgroup
                  Or a URL like https://gitlab.com/my-org/some-subgroup

Options:
  -u, --update            Pass -u to ghq get (fetch updates for existing clones)
  -j, --parallel N        Clone up to N repos in parallel (default: 4)
      --include-archived  Include archived projects (default: skip them)
  -h, --help              Show this help

Examples:
  ghq-gitlab-group my-org/team-tools
  ghq-gitlab-group -j 8 -u my-org
EOF
	exit "${1:-0}"
}

UPDATE=""
PARALLEL=4
ARCHIVED="false"
GROUP=""

while [[ $# -gt 0 ]]; do
	case "$1" in
	-u | --update)
		UPDATE="-u"
		shift
		;;
	-j | --parallel)
		PARALLEL="$2"
		shift 2
		;;
	--include-archived)
		ARCHIVED="true"
		shift
		;;
	-h | --help) usage 0 ;;
	-*)
		echo "Unknown flag: $1" >&2
		usage 1
		;;
	*)
		if [[ -n $GROUP ]]; then
			echo "Multiple group paths given." >&2
			usage 1
		fi
		GROUP="$1"
		shift
		;;
	esac
done

[[ -z $GROUP ]] && usage 1

# Strip protocol + host if a URL was pasted in.
GROUP="${GROUP#https://gitlab.com/}"
GROUP="${GROUP#http://gitlab.com/}"
GROUP="${GROUP#git@gitlab.com:}"
GROUP="${GROUP%.git}"
GROUP="${GROUP%/}"

if ! glab auth status >/dev/null 2>&1; then
	echo "glab is not authenticated. Run: glab auth login" >&2
	exit 1
fi

# GitLab REST wants the group id or URL-encoded full path.
ENC=$(jq -rn --arg s "$GROUP" '$s | @uri')

echo "Listing projects in group: $GROUP"
PROJECTS=$(glab api --paginate \
	"groups/$ENC/projects?include_subgroups=true&per_page=100&archived=$ARCHIVED&simple=true" |
	jq -r '.[].path_with_namespace')

if [[ -z $PROJECTS ]]; then
	echo "No projects found under $GROUP." >&2
	exit 1
fi

COUNT=$(printf '%s\n' "$PROJECTS" | wc -l)
echo "Found $COUNT project(s). Cloning into $(ghq root) with -j$PARALLEL..."
echo ""

# Buffer each child's output so parallel ghq invocations don't interleave
# their lines mid-write. $UPDATE is exported for the child shells; $1 is the
# {} positional arg from xargs — both must NOT expand in the parent.
export UPDATE
# shellcheck disable=SC2016
printf '%s\n' "$PROJECTS" |
	xargs -P "$PARALLEL" -I {} bash -c '
      out=$(ghq get $UPDATE "gitlab.com/$1" 2>&1) || rc=$?
      printf "%s\n" "$out"
      exit "${rc:-0}"
    ' _ {}

GROUP_DIR="$(ghq root)/gitlab.com/$GROUP"

echo ""
echo "Done."
echo ""
echo "Next: warm devShells so the store is hot for these repos:"
echo "  warm-flake-cache $GROUP_DIR"
