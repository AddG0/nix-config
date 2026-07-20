#!/usr/bin/env bash
# Clone every project in a GitLab group (recursive, includes subgroups) into
# ghq's managed layout under $(ghq root).

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ghq-gitlab-group [-u] [-j N] [--include-archived] [--no-prune] [-n] <group-path>

Clones every project in a GitLab group (and its subgroups) via ghq.

Before cloning it reconciles local clones with GitLab: projects that were
renamed or transferred are moved on disk (no re-clone), and clones whose
project is gone (deleted / scheduled for deletion) are removed.

Arguments:
  <group-path>    Full GitLab group path, e.g. my-org/some-subgroup
                  Or a URL like https://gitlab.com/my-org/some-subgroup

Options:
  -u, --update            Pass -u to ghq get (fetch updates for existing clones)
  -j, --parallel N        Clone up to N repos in parallel (default: 4)
      --include-archived  Include archived projects (default: skip them)
      --no-prune          Relocate moved clones but never delete anything
  -n, --dry-run           Show the reconcile plan and exit; change nothing
  -h, --help              Show this help

Examples:
  ghq-gitlab-group my-org/team-tools
  ghq-gitlab-group -j 8 -u my-org
  ghq-gitlab-group -n my-org         # preview moves/deletes only
EOF
  exit "${1:-0}"
}

UPDATE=""
PARALLEL=4
ARCHIVED="false"
PRUNE="true"
DRY_RUN="false"
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
  --no-prune)
    PRUNE="false"
    shift
    ;;
  -n | --dry-run)
    DRY_RUN="true"
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
  echo "glab is not authenticated. Run: glab-login" >&2
  exit 1
fi

# GitLab REST wants group/project ids URL-encoded.
enc() { jq -rn --arg s "$1" '$s | @uri'; }

ROOT="$(ghq root)"
GITLAB_DIR="$ROOT/gitlab.com"
ENC=$(enc "$GROUP")

echo "Listing projects in group: $GROUP"

# Run glab on its own (don't pipe straight into jq). On failure — e.g. the
# group not existing — glab prints its own "404 Group Not Found" to stderr
# and exits non-zero; piping into jq would instead surface a confusing
# "Cannot index string with string" parse error. Check the exit status and
# give a clean message instead.
if ! PROJECTS_JSON=$(glab api --paginate \
  "groups/$ENC/projects?include_subgroups=true&per_page=100&archived=$ARCHIVED&simple=true"); then
  echo "Could not list group '$GROUP' — it may not exist or you may not have access to it." >&2
  exit 1
fi

# Skip projects GitLab has scheduled for deletion: their path is renamed with a
# `-deletion_scheduled-<id>` suffix during the retention window and they must
# not be (re)cloned. marked_for_deletion_on covers it too when present.
PROJECTS=$(printf '%s' "$PROJECTS_JSON" |
  jq -r '.[]
    | select((.marked_for_deletion_on // null) == null)
    | select(.path_with_namespace | test("-deletion_scheduled-[0-9]+$") | not)
    | .path_with_namespace')

if [[ -z $PROJECTS ]]; then
  echo "No projects found under $GROUP." >&2
  exit 1
fi

GROUP_DIR="$GITLAB_DIR/$GROUP"

# Would removing this clone lose local-only work (uncommitted, untracked, or
# stashed)? Such clones are kept for manual review rather than deleted.
has_local_work() {
  [[ -n "$(git -C "$1" status --porcelain 2>/dev/null)" ]] && return 0
  [[ -n "$(git -C "$1" stash list 2>/dev/null)" ]] && return 0
  return 1
}

# Move a clone to its new path and repoint origin (no re-clone).
relocate_clone() {
  local from="$GITLAB_DIR/$1" to="$GITLAB_DIR/$2" url
  mkdir -p "$(dirname "$to")"
  mv "$from" "$to"
  # The old path segment appears verbatim in the remote URL; swap it in place.
  url=$(git -C "$to" remote get-url origin 2>/dev/null || true)
  [[ -n $url && $url == *"$1"* ]] && git -C "$to" remote set-url origin "${url/$1/$2}"
  rmdir -p --ignore-fail-on-non-empty "$(dirname "$from")" 2>/dev/null || true
}

remove_clone() {
  rm -rf "${GITLAB_DIR:?}/$1"
  rmdir -p --ignore-fail-on-non-empty "$(dirname "$GITLAB_DIR/$1")" 2>/dev/null || true
}

# Reconcile local clones with GitLab before cloning: relocate clones whose
# project was renamed/transferred (GitLab redirects the old path to the current
# one, so we can move instead of re-cloning) and remove clones whose project is
# gone. Runs first so the clone loop below sees repos already at their new home.
reconcile() {
  [[ -d $GROUP_DIR ]] || return 0

  local -A current=() moves=()
  local deletes=() kept=() unknown=()
  local p dir rel out cur id

  # Authoritative current paths (unfiltered — a clone matching any live path,
  # even archived or deletion-scheduled, is left for the per-folder check).
  while IFS= read -r p; do current["$p"]=1; done < <(
    printf '%s' "$PROJECTS_JSON" | jq -r '.[].path_with_namespace'
  )

  # Outermost clones only: prune descent once a .git is found so nested repos
  # (terraform module caches, meta-repo sub-clones) are never touched.
  while IFS= read -r dir; do
    rel="${dir#"$GITLAB_DIR"/}"
    [[ -n ${current["$rel"]:-} ]] && continue

    out=$(glab api "projects/$(enc "$rel")" 2>&1) || true
    id=$(printf '%s' "$out" | jq -r '.id // empty' 2>/dev/null || true)
    cur=$(printf '%s' "$out" | jq -r '.path_with_namespace // empty' 2>/dev/null || true)

    if [[ -n $id && -n $cur ]]; then
      if [[ $cur =~ -deletion_scheduled-[0-9]+$ ]]; then
        if has_local_work "$dir"; then
          kept+=("$rel (deletion-scheduled, has local work)")
        else deletes+=("$rel"); fi
      elif [[ $cur == "$rel" ]]; then
        : # archived / unchanged
      elif [[ -e "$GITLAB_DIR/$cur" ]]; then
        kept+=("$rel -> $cur (destination already exists)")
      else
        moves["$rel"]="$cur"
      fi
    elif printf '%s' "$out" | grep -q '(HTTP 404)'; then
      if has_local_work "$dir"; then
        kept+=("$rel (gone, has local work)")
      else deletes+=("$rel"); fi
    else
      # Network / 5xx / auth / rate-limit — never destructive on uncertainty.
      unknown+=("$rel")
    fi
  done < <(find "$GROUP_DIR" -type d -exec test -e '{}/.git' ';' -print -prune 2>/dev/null)

  [[ $PRUNE == true ]] || deletes=()

  if ((${#moves[@]})); then
    echo "Moved on GitLab — relocating clone (no re-clone):"
    for rel in "${!moves[@]}"; do
      echo "  $rel -> ${moves[$rel]}"
      [[ $DRY_RUN == true ]] || relocate_clone "$rel" "${moves[$rel]}"
    done
  fi

  if ((${#deletes[@]})); then
    echo "Gone from GitLab — removing clone:"
    for rel in "${deletes[@]}"; do
      echo "  $rel"
      [[ $DRY_RUN == true ]] || remove_clone "$rel"
    done
  fi

  ((${#kept[@]})) && {
    echo "Skipped (needs manual review):"
    printf '  %s\n' "${kept[@]}"
  }
  ((${#unknown[@]})) && {
    echo "Skipped (GitLab lookup inconclusive — left untouched):"
    printf '  %s\n' "${unknown[@]}"
  }
  ((${#moves[@]} + ${#deletes[@]} + ${#kept[@]} + ${#unknown[@]})) && echo ""
  return 0
}

reconcile

if [[ $DRY_RUN == true ]]; then
  echo "Dry run — no changes made. Re-run without -n to apply."
  exit 0
fi

COUNT=$(printf '%s\n' "$PROJECTS" | wc -l)
echo "Found $COUNT project(s). Cloning into $ROOT with -j$PARALLEL..."
echo ""

# Buffer each child's output so parallel ghq invocations don't interleave
# their lines mid-write. $UPDATE is exported for the child shells; $1 is the
# {} positional arg from xargs — both must NOT expand in the parent.
# (Nested GitLab subgroup paths are preserved by the `ghq."https://gitlab.com/".vcs
# = git` setting in ../ghq.nix, which disables ghq's path-truncating VCS probe.)
export UPDATE
# shellcheck disable=SC2016
printf '%s\n' "$PROJECTS" |
  xargs -P "$PARALLEL" -I {} bash -c '
      out=$(ghq get $UPDATE "gitlab.com/$1" 2>&1) || rc=$?
      printf "%s\n" "$out"
      exit "${rc:-0}"
    ' _ {}

echo ""
echo "Done."
echo ""
echo "Next: warm devShells so the store is hot for these repos:"
echo "  warm-flake-cache $GROUP_DIR"
