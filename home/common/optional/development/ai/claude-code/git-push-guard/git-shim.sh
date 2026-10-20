# Sits ahead of git on claude's PATH; blocks `push` unless ALLOW_GIT_PUSH is set.
args=("$@")
i=0
while ((i < ${#args[@]})); do
  case ${args[i]} in
  -C | -c | --git-dir | --work-tree | --namespace | --config-env) i=$((i + 2)) ;;
  -*) i=$((i + 1)) ;;
  *) break ;;
  esac
done
if [[ ${args[i]-} == push && -z ${ALLOW_GIT_PUSH-} ]]; then
  echo "git push blocked: rerun as ALLOW_GIT_PUSH=1 git $*" >&2
  exit 1
fi

self=${0%/*}
IFS=: read -ra dirs <<<"$PATH"
rest=
for d in "${dirs[@]}"; do
  [[ $d == "$self" ]] || rest+=${rest:+:}$d
done
real=$(PATH=$rest command -v git) || {
  echo "git-push-guard: no git on PATH besides $self" >&2
  exit 127
}
exec "$real" "$@"
