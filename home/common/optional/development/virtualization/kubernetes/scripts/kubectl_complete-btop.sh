#!/bin/bash
# kubectl_complete-btop: shell-completion helper for `kubectl btop`.
# kubectl's completion machinery invokes this with the words typed after
# `btop`; it prints one candidate per line on stdout.

set -uo pipefail

args=("$@")
n=${#args[@]}
cur=""
prev=""
((n >= 1)) && cur="${args[$((n - 1))]}"
((n >= 2)) && prev="${args[$((n - 2))]}"

# Scan already-typed args for -n/--namespace value and the pod name
ns=""
pod=""
skip=false
for ((i = 0; i < n - 1; i++)); do
	if $skip; then
		skip=false
		continue
	fi
	case "${args[i]}" in
	-n | --namespace)
		ns="${args[i + 1]:-}"
		skip=true
		;;
	-c | --container) skip=true ;;
	-*) ;;
	*) [[ -z $pod ]] && pod="${args[i]}" ;;
	esac
done

ns_arg=()
[[ -n $ns ]] && ns_arg=(-n "$ns")

# Always suppress shell filename fallback (cobra directive 4 = NoFileComp)
trap 'echo :4' EXIT

if [[ $cur == -* ]]; then
	printf '%s\n' -n --namespace -c --container -h --help
	exit 0
fi

# Flag values. Each listing uses jsonpath `range … \n` so every item ends
# with a newline — otherwise the final item gets the `:4` directive glued
# onto it by the cobra completion parser.
case "$prev" in
-n | --namespace)
	kubectl get ns \
		-o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null
	exit 0
	;;
-c | --container)
	[[ -n $pod ]] && kubectl "${ns_arg[@]}" get pod "$pod" \
		-o jsonpath='{range .spec.containers[*]}{.name}{"\n"}{end}' 2>/dev/null
	exit 0
	;;
esac

kubectl "${ns_arg[@]}" get pods \
	-o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null
