#!/usr/bin/env bash
# t3code-nvim <path>[:line[:column]]
#
# Mirrors glmr-open: ghostty for the window, and a login shell so nvim and its
# plugins resolve from the interactive PATH.
set -euo pipefail

target="${1-}"
if [ -z "$target" ]; then
  echo "t3code-nvim: no path given" >&2
  exit 2
fi

line=""
if [ ! -e "$target" ]; then
  # Only strip a position suffix when the literal path does not exist, so paths
  # that genuinely contain a colon still open.
  case "$target" in
  *:[0-9]*)
    candidate=${target%:*}
    suffix=${target##*:}
    case "$candidate" in
    *:[0-9]*)
      if [ -e "${candidate%:*}" ]; then
        line=${candidate##*:}
        target=${candidate%:*}
      fi
      ;;
    *)
      if [ -e "$candidate" ]; then
        line=$suffix
        target=$candidate
      fi
      ;;
    esac
    ;;
  esac
fi

if [ -d "$target" ]; then
  dir=$target
  file=""
else
  dir=$(dirname -- "$target")
  file=$target
fi

# The inner shell is single-quoted and takes $1..$3 positionally, so a path
# never enters the command string.
# shellcheck disable=SC2016
exec ghostty -e bash -lc '
  set -euo pipefail
  cd "$1"
  if [ -n "$3" ]; then
    exec nvim "+$3" -- "$2"
  elif [ -n "$2" ]; then
    exec nvim -- "$2"
  else
    exec nvim
  fi
' bash "$dir" "$file" "$line"
