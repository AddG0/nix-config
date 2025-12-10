#compdef kubectl-cloud-shell

_kubectl-cloud-shell() {
  local context state line
  typeset -A opt_args

  _arguments -C \
    '--bare[Use bare mode with minimal zsh setup instead of home-manager]' \
    '*:: :->kubectl_args'

  if [[ $state == kubectl_args ]]; then
    # Prepend "kubectl run pod-name" to simulate kubectl run completion
    words=( kubectl run pod-name "${words[@]}" )
    # Adjust CURRENT: add 3 for the 3 new words we prepended
    (( CURRENT = CURRENT + 3 ))

    # Restart completion with the simulated command line
    _normal
  fi
}

_kubectl-cloud-shell "$@"
