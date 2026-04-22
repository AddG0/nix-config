#!/bin/bash
# kubectl-btop: attach btop to a pod via an ephemeral debug container sharing
# the target's PID namespace. Inlines local ~/.config/btop/btop.conf if present.
#
# Two-step approach (add container, wait, exec) avoids kubectl debug -it's
# attach race against ephemeral containers on non-root pods. A custom security
# profile with runAsUser: 0 (non-privileged) gives the ephemeral container a
# proper PTY on non-root targets while staying inside PodSecurityAdmission
# "baseline" policy — works on GKE Autopilot.

set -euo pipefail

usage() {
	cat <<'EOF'
Usage: kubectl btop [-n NAMESPACE] [-c CONTAINER] POD

Attach btop to a pod's process namespace via an ephemeral debug container.
If ~/.config/btop/btop.conf exists locally, it's inlined so btop uses your theme.
EOF
}

NS="" CONTAINER="" POD=""
while [[ $# -gt 0 ]]; do
	case "$1" in
	-n | --namespace)
		NS="$2"
		shift 2
		;;
	-c | --container)
		CONTAINER="$2"
		shift 2
		;;
	-h | --help)
		usage
		exit 0
		;;
	-*)
		echo "unknown option: $1" >&2
		usage
		exit 1
		;;
	*)
		POD="$1"
		shift
		;;
	esac
done
[[ -z $POD ]] && {
	usage
	exit 1
}

NS_ARG=()
[[ -n $NS ]] && NS_ARG=(-n "$NS")

# Auto-detect container if the pod has only one
if [[ -z $CONTAINER ]]; then
	names=$(kubectl "${NS_ARG[@]}" get pod "$POD" -o jsonpath='{.spec.containers[*].name}')
	if [[ $(echo "$names" | wc -w) -eq 1 ]]; then
		CONTAINER="$names"
	else
		echo "pod has multiple containers, pass -c:" >&2
		# shellcheck disable=SC2086
		printf '  %s\n' $names >&2
		exit 1
	fi
fi

DEBUGGER="btop-$(date +%s)"

# Custom container security profile: root UID so the ephemeral container gets a
# proper PTY, but no privileged mode / extra caps (Autopilot-compatible).
PROFILE=$(mktemp --suffix=.json)
trap 'rm -f "$PROFILE"' EXIT
printf '{"securityContext":{"runAsUser":0,"runAsNonRoot":false}}' >"$PROFILE"

# Step 1: add the ephemeral container and let it sleep so it's ready to exec into.
kubectl "${NS_ARG[@]}" debug "$POD" \
	--target="$CONTAINER" \
	--container="$DEBUGGER" \
	--image=nixery.dev/shell/btop \
	--profile=general \
	--custom="$PROFILE" \
	-- sh -c "sleep 3600" >/dev/null

# Step 2: wait for it to transition to Running (nixery cold-pull can take ~30s).
for _ in {1..120}; do
	state=$(kubectl "${NS_ARG[@]}" get pod "$POD" \
		-o jsonpath="{.status.ephemeralContainerStatuses[?(@.name=='$DEBUGGER')].state.running.startedAt}" 2>/dev/null || true)
	[[ -n $state ]] && break
	sleep 0.5
done
if [[ -z ${state:-} ]]; then
	echo "debug container did not reach Running within 60s" >&2
	exit 1
fi

# Step 3: inline config (if any) and exec btop via a real PTY.
SETUP="mkdir -p /dev/shm/.config/btop 2>/dev/null; "
if [[ -f $HOME/.config/btop/btop.conf ]]; then
	b64=$(base64 -w0 <"$HOME/.config/btop/btop.conf")
	SETUP+="printf %s '$b64' | base64 -d > /dev/shm/.config/btop/btop.conf 2>/dev/null; "
fi

exec kubectl "${NS_ARG[@]}" exec -it "$POD" -c "$DEBUGGER" -- \
	sh -c "${SETUP}HOME=/dev/shm btop --force-utf"
