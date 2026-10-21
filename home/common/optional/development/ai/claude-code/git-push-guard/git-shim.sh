# Sits ahead of git on claude's PATH; blocks `push` unless ALLOW_GIT_PUSH=1.
args=("$@")
i=0
while ((i < ${#args[@]})); do
  case ${args[i]} in
  -C | -c | --git-dir | --work-tree | --namespace | --config-env) i=$((i + 2)) ;;
  -*) i=$((i + 1)) ;;
  *) break ;;
  esac
done
if [[ ${args[i]-} == push && ${ALLOW_GIT_PUSH-} != 1 ]]; then
  echo "git push blocked: rerun as ALLOW_GIT_PUSH=1 git $*" >&2
  exit 1
fi

exec "$realGit" "$@"
