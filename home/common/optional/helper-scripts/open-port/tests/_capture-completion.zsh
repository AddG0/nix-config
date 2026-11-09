# Prints what zsh's own completion offers for a command line, one "[candidate] -- description" per line.
# Usage: zsh -f _capture-completion.zsh <fpath dir> <PATH> <line>. The technique is zsh-capture-completion's.
if [[ $1 == --init ]]; then
  PROMPT=
  autoload -Uz compinit
  compinit -u -D
  bindkey '^M' undefined
  bindkey '^J' undefined
  bindkey '^I' complete-word
  # A NUL line marks where the completion's output starts and ends; exit ends the session once it has run.
  null-line() { echo -E - $'\0' }
  compprefuncs=(null-line)
  comppostfuncs=(null-line exit)
  zstyle ':completion:*' list-grouped false
  zstyle ':completion:*' insert-tab false
  zstyle ':completion:*' list-separator ''
  zmodload zsh/zutil
  # Prints each match compadd is handed instead of inserting it.
  compadd() {
    if [[ ${@[1,(i)(-|--)]} == *-(O|A|D)\ * ]]; then
      builtin compadd "$@"
      return $?
    fi
    typeset -a __hits __dscr __tmp
    if (( $@[(I)-d] )); then
      __tmp=${@[$[${@[(i)-d]}+1]]}
      if [[ $__tmp == \(* ]]; then eval "__dscr=$__tmp"; else __dscr=("${(@P)__tmp}"); fi
    fi
    builtin compadd -A __hits -D __dscr "$@"
    setopt localoptions norcexpandparam extendedglob
    typeset -A apre hpre hsuf asuf
    zparseopts -E P:=apre p:=hpre S:=asuf s:=hsuf
    [[ -n $__hits ]] || return
    local i dscr
    for i in {1..$#__hits}; do
      dscr=
      (( $#__dscr >= i )) && dscr=${${__dscr[$i]}##$__hits[$i] #}
      [[ -n ${dscr## #} ]] && dscr=" -- ${dscr##-- #}" || dscr=
      echo -E - "[$IPREFIX$apre$hpre$__hits[$i]$hsuf$asuf]$dscr"
    done
  }
  return
fi

zmodload zsh/zpty
zpty capture zsh -f -i
zpty -w capture "PATH=${(q)2}; fpath=(${(q)1} \$fpath); source ${(q)0} --init"
zpty -w capture "$3"$'\t'
integer started=0
while zpty -r capture; do :; done | while IFS= read -r line; do
  if [[ $line == *$'\0\r' ]]; then (( started++ )) && return 0 || continue; fi
  (( started )) && echo -E - "${line%$'\r'}"
done
