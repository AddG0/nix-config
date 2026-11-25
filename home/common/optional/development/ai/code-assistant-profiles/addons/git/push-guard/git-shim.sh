# Sits ahead of git on claude's PATH; blocks `push`, directly or through an alias, unless ALLOW_GIT_PUSH=1.
# shellcheck shell=bash disable=SC2154 # realGit is prepended by default.nix
if [[ ${ALLOW_GIT_PUSH-} == 1 ]]; then
  exec "$realGit" "$@"
fi

blocked() {
  echo "git push blocked: rerun as ALLOW_GIT_PUSH=1 git $*" >&2
  exit 1
}

args=("$@")
i=0
# Bounds alias chains; git itself stops a looping one.
maxAliasDepth=32
expansions=0
while ((i < ${#args[@]})); do
  case ${args[i]} in
  # git 2.56's global options that take their value as the next word.
  -C | -c | --git-dir | --work-tree | --namespace | --config-env | --attr-source) i=$((i + 2)) ;;
  # These print and exit before any command runs, so the rest is never a command.
  -h | --help | -v | --version) exec "$realGit" "$@" ;;
  -*) i=$((i + 1)) ;;
  *)
    sub=${args[i]}
    if [[ $sub == push ]]; then
      blocked "$@"
    fi
    # Resolved with the options before it, so `-c alias.x=push` and `-C <repo>` count.
    if ((expansions >= maxAliasDepth)) || ! alias=$("$realGit" "${args[@]:0:i}" config --get "alias.$sub" 2>/dev/null); then
      break
    fi
    # git runs a command over an alias of the same name.
    commands=$'\n'$("$realGit" --list-cmds=main,others)$'\n'
    if [[ $commands == *$'\n'"$sub"$'\n'* ]]; then
      break
    fi
    expansions=$((expansions + 1))
    if [[ $alias == '!'* ]]; then
      if [[ $alias == *push* ]]; then
        blocked "$@"
      fi
      break
    fi
    read -ra words <<<"$alias"
    args=("${args[@]:0:i}" "${words[@]}" "${args[@]:i+1}")
    ;;
  esac
done

exec "$realGit" "$@"
