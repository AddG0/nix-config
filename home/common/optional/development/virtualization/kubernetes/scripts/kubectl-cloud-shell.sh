#!/bin/bash
set -euo pipefail

# Configuration
POD_NAME="nix-cloud-shell-$(date +%s)"
POD_LABEL="app=nix-cloud-shell"
POD_IMAGE="nixos/nix:latest"
POD_HOME="/home/addg"
POD_TIMEOUT=21600 # 6 hours

BARE_MODE=false
COPY_LOCAL=""
COPY_REMOTE="$POD_HOME/workspace"
SSH_AGENT=false
SSH_AGENT_SOCK="/tmp/ssh-agent.sock"
USE_LOCAL_FLAKE=false
FLAKE_REMOTE="$POD_HOME/.nix-config"

MEMORY_REQUEST="512Mi"
MEMORY_LIMIT="4Gi"
CPU_REQUEST="250m"
CPU_LIMIT="2"
EPHEMERAL_STORAGE="10Gi"

# Session management
ATTACH_POD=""
LIST_PODS=false
CLEAN_ALL=false

KUBECTL_ARGS=()
BARE_NIX_PACKAGES=("iputils" "bind" "tmux")

# Helpers
log() { echo "[cloud-shell] $*"; }
log_error() { echo "[cloud-shell] ERROR: $*" >&2; }

usage() {
	cat <<-EOF
		Usage: kubectl-cloud-shell [OPTIONS] [-- KUBECTL_ARGS...]

		Options:
		  --bare              Use minimal shell without home-manager
		  --local-flake       Copy \$FLAKE to pod and use it instead of remote
		  --copy <dir>        Copy local directory to pod at startup
		  --ssh-agent         Forward local SSH agent to pod
		  --memory <size>     Memory request/limit (default: ${MEMORY_REQUEST}/${MEMORY_LIMIT})
		  --cpu <cores>       CPU request/limit (default: ${CPU_REQUEST}/${CPU_LIMIT})
		  --storage <size>    Ephemeral storage (default: ${EPHEMERAL_STORAGE})
		  --attach <name>     Attach to existing pod
		  --list              List running cloud-shell pods
		  --clean             Delete all cloud-shell pods
		  --help              Show this help message

		Session Management:
		  On exit, choose to keep pod running for later
		  Use --list to see running pods
		  Use --attach <pod-name> to reattach
		  Tip: Run tmux inside pod for Ctrl+B D detach

		Examples:
		  kubectl-cloud-shell
		  kubectl-cloud-shell --bare
		  kubectl-cloud-shell --list
		  kubectl-cloud-shell --attach nix-cloud-shell-123456
		  kubectl-cloud-shell --attach nix-cloud-shell-123456 --ssh-agent
		  kubectl-cloud-shell --local-flake
		  kubectl-cloud-shell --copy ~/projects/myapp
		  kubectl-cloud-shell --ssh-agent --copy . -n my-namespace
	EOF
}

parse_args() {
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--bare)
			BARE_MODE=true
			shift
			;;
		--local-flake)
			USE_LOCAL_FLAKE=true
			shift
			;;
		--copy)
			if [[ -n "${2:-}" && "$2" != --* ]]; then
				COPY_LOCAL="$(realpath "$2")"
				shift 2
			else
				log_error "--copy requires a local directory path"
				exit 1
			fi
			;;
		--ssh-agent)
			SSH_AGENT=true
			shift
			;;
		--memory)
			if [[ -n "${2:-}" && "$2" != --* ]]; then
				MEMORY_REQUEST="$2"
				MEMORY_LIMIT="$2"
				shift 2
			else
				log_error "--memory requires a size (e.g., 2Gi)"
				exit 1
			fi
			;;
		--cpu)
			if [[ -n "${2:-}" && "$2" != --* ]]; then
				CPU_REQUEST="$2"
				CPU_LIMIT="$2"
				shift 2
			else
				log_error "--cpu requires a value (e.g., 2)"
				exit 1
			fi
			;;
		--storage)
			if [[ -n "${2:-}" && "$2" != --* ]]; then
				EPHEMERAL_STORAGE="$2"
				shift 2
			else
				log_error "--storage requires a size (e.g., 10Gi)"
				exit 1
			fi
			;;
		--attach)
			if [[ -n "${2:-}" && "$2" != --* ]]; then
				ATTACH_POD="$2"
				shift 2
			else
				log_error "--attach requires a pod name"
				exit 1
			fi
			;;
		--list)
			LIST_PODS=true
			shift
			;;
		--clean)
			CLEAN_ALL=true
			shift
			;;
		--help | -h)
			usage
			exit 0
			;;
		--)
			shift
			KUBECTL_ARGS+=("$@")
			break
			;;
		*)
			KUBECTL_ARGS+=("$1")
			shift
			;;
		esac
	done
}

validate() {
	if [[ "$USE_LOCAL_FLAKE" == "true" ]]; then
		if [[ -z "${FLAKE:-}" ]]; then
			log_error "\$FLAKE environment variable is not set"
			exit 1
		fi
		if [[ ! -d "$FLAKE" ]]; then
			log_error "Flake directory '$FLAKE' does not exist"
			exit 1
		fi
	fi

	if [[ -n "$COPY_LOCAL" && ! -d "$COPY_LOCAL" ]]; then
		log_error "Copy directory '$COPY_LOCAL' does not exist"
		exit 1
	fi

	if [[ "$SSH_AGENT" == "true" ]]; then
		if [[ -z "${SSH_AUTH_SOCK:-}" ]]; then
			log_error "SSH_AUTH_SOCK is not set. Is ssh-agent running?"
			exit 1
		fi
		if [[ ! -S "$SSH_AUTH_SOCK" ]]; then
			log_error "SSH_AUTH_SOCK ($SSH_AUTH_SOCK) is not a valid socket"
			exit 1
		fi
	fi
}

# List running cloud-shell pods
list_pods() {
	log "Cloud-shell pods:"
	kubectl "${KUBECTL_ARGS[@]}" get pods \
		--selector="$POD_LABEL" \
		-o custom-columns='NAME:.metadata.name,STATUS:.status.phase,AGE:.metadata.creationTimestamp' \
		2>/dev/null || echo "No cloud-shell pods found"
}

# Delete all cloud-shell pods
clean_all() {
	log "Deleting all cloud-shell pods..."
	kubectl "${KUBECTL_ARGS[@]}" delete pods --selector="$POD_LABEL" --wait=false 2>/dev/null || true
	log "Done"
}

# Attach to existing pod
attach_pod() {
	local pod="$1"
	POD_NAME="$pod"

	# Verify pod exists and is running
	local pod_status
	pod_status=$(kubectl "${KUBECTL_ARGS[@]}" get pod "$pod" -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
	if [[ "$pod_status" != "Running" ]]; then
		log_error "Pod '$pod' is not running (status: $pod_status)"
		exit 1
	fi

	log "Attaching to pod $pod..."

	# Setup SSH agent if requested
	if [[ "$SSH_AGENT" == "true" ]]; then
		# Remove stale socket if exists
		kubectl "${KUBECTL_ARGS[@]}" exec "$pod" -- rm -f "$SSH_AGENT_SOCK" 2>/dev/null || true
		ssh_agent_setup
	fi

	trap 'ssh_agent_cleanup' EXIT
	trap '' SIGINT SIGTERM

	# Write SSH_AUTH_SOCK to .zshrc.imperitive so it persists past zsh init
	if [[ "$SSH_AGENT" == "true" ]]; then
		kubectl "${KUBECTL_ARGS[@]}" exec "$pod" -- \
			sh -c "echo 'export SSH_AUTH_SOCK=\"$SSH_AGENT_SOCK\"' > $POD_HOME/.zshrc.imperitive"
	fi

	# shellcheck disable=SC2016 # $PATH must expand in pod, not locally
	kubectl "${KUBECTL_ARGS[@]}" exec -it "$pod" -- \
		sh -c 'export PATH="'"$POD_HOME"'/.nix-profile/bin:$PATH" SHELL="'"$POD_HOME"'/.nix-profile/bin/zsh"; exec "'"$POD_HOME"'/.nix-profile/bin/zsh" -l'
}

# Feature: Copy local flake to pod
flake_setup() {
	[[ "$USE_LOCAL_FLAKE" != "true" ]] && return 0
	log "Copying flake $FLAKE -> $POD_NAME:$FLAKE_REMOTE"
	kubectl "${KUBECTL_ARGS[@]}" cp "$FLAKE" "$POD_NAME:$FLAKE_REMOTE"
}

# Feature: Copy local directory to pod
copy_setup() {
	[[ -z "$COPY_LOCAL" ]] && return 0
	log "Copying $COPY_LOCAL -> $POD_NAME:$COPY_REMOTE"
	kubectl "${KUBECTL_ARGS[@]}" cp "$COPY_LOCAL" "$POD_NAME:$COPY_REMOTE"
}

# SSH agent forwarding: local socket <-> kubectl exec stdio <-> pod socket
SSH_TUNNEL_PID=""

ssh_agent_setup() {
	[[ "$SSH_AGENT" != "true" ]] && return 0
	log "Setting up SSH agent forwarding..."

	if [[ "$BARE_MODE" == "true" ]]; then
		log "Copying git and ssh config to pod..."
		kubectl "${KUBECTL_ARGS[@]}" cp "$HOME/.config/git/config" "$POD_NAME:$POD_HOME/.gitconfig"
		kubectl "${KUBECTL_ARGS[@]}" exec "$POD_NAME" -- mkdir -p "$POD_HOME/.ssh"
		[[ -f "$HOME/.ssh/known_hosts" ]] && kubectl "${KUBECTL_ARGS[@]}" cp "$HOME/.ssh/known_hosts" "$POD_NAME:$POD_HOME/.ssh/known_hosts"
	fi

	local kubectl_cmd="kubectl"
	[[ ${#KUBECTL_ARGS[@]} -gt 0 ]] && kubectl_cmd="kubectl ${KUBECTL_ARGS[*]}"

	local tunnel_log="/tmp/cloud-shell-tunnel-$$.log"
	log "Starting SSH tunnel (log: $tunnel_log)"

	socat \
		"EXEC:$kubectl_cmd exec -i $POD_NAME -- nix --extra-experimental-features nix-command --extra-experimental-features flakes run nixpkgs\#socat -- UNIX-LISTEN\:${SSH_AGENT_SOCK} STDIO" \
		"UNIX:$SSH_AUTH_SOCK" 2>"$tunnel_log" &
	SSH_TUNNEL_PID=$!

	log "Waiting for SSH agent socket..."
	for _ in {1..60}; do
		if kubectl "${KUBECTL_ARGS[@]}" exec "$POD_NAME" -- test -S "$SSH_AGENT_SOCK" 2>/dev/null; then
			log "SSH agent forwarding active (socket: $SSH_AGENT_SOCK)"
			return 0
		fi
		if ! kill -0 "$SSH_TUNNEL_PID" 2>/dev/null; then
			log_error "SSH agent tunnel failed. Log:"
			cat "$tunnel_log" >&2 2>/dev/null || true
			return 1
		fi
		sleep 0.5
	done

	log_error "SSH agent socket creation timed out. Log:"
	cat "$tunnel_log" >&2 2>/dev/null || true
	return 1
}

ssh_agent_cleanup() {
	[[ "$SSH_AGENT" != "true" ]] && return 0
	log "Stopping SSH agent forwarding..."
	[[ -n "$SSH_TUNNEL_PID" ]] && kill "$SSH_TUNNEL_PID" 2>/dev/null || true
}

# Pod management
build_pod_overrides() {
	local flake_url
	if [[ "$USE_LOCAL_FLAKE" == "true" ]]; then
		flake_url="$FLAKE_REMOTE#cloud-shell"
	else
		flake_url="git+https://github.com/AddG0/nix-config?ref=main#cloud-shell"
	fi

	local env_json='[
		{"name": "HOME", "value": "'"$POD_HOME"'"},
		{"name": "USER", "value": "addg"},
		{"name": "BARE_MODE", "value": "'"$BARE_MODE"'"},
		{"name": "BARE_PACKAGES_STR", "value": "'"${BARE_NIX_PACKAGES[*]}"'"},
		{"name": "FLAKE_URL", "value": "'"$flake_url"'"}'

	[[ "$SSH_AGENT" == "true" ]] && env_json="$env_json"',
		{"name": "SSH_AUTH_SOCK", "value": "'"$SSH_AGENT_SOCK"'"}'
	env_json="$env_json]"

	cat <<-EOF
		{
			"metadata": {
				"labels": {"app": "nix-cloud-shell"}
			},
			"spec": {
				"activeDeadlineSeconds": $POD_TIMEOUT,
				"containers": [{
					"name": "$POD_NAME",
					"image": "$POD_IMAGE",
					"command": ["sh", "-c", "mkdir -p $COPY_REMOTE && sleep infinity"],
					"env": $env_json,
					"resources": {
						"requests": {"memory": "$MEMORY_REQUEST", "cpu": "$CPU_REQUEST", "ephemeral-storage": "$EPHEMERAL_STORAGE"},
						"limits": {"memory": "$MEMORY_LIMIT", "cpu": "$CPU_LIMIT", "ephemeral-storage": "$EPHEMERAL_STORAGE"}
					}
				}]
			}
		}
	EOF
}

get_init_script() {
	cat <<-'INIT_EOF'
		set -e

		mkdir -p ~/.config/nix
		cat > ~/.config/nix/nix.conf <<-NIXCONF
			experimental-features = nix-command flakes
			accept-flake-config = true
			max-jobs = 4
			cores = 4
		NIXCONF

		if [ "$BARE_MODE" = "true" ]; then
		  echo "====================================="
		  echo "Bare Nix Shell (zsh + oh-my-zsh)"
		  echo "====================================="

		  # glibc provides iconv needed by oh-my-zsh
		  PKGS="nixpkgs#{zsh,oh-my-zsh,zsh-syntax-highlighting,zsh-autosuggestions,glibc,coreutils}"
		  for pkg in $BARE_PACKAGES_STR; do
		    PKGS="$PKGS nixpkgs#$pkg"
		  done
		  eval "nix profile add $PKGS"

		  cat > ~/.zshrc <<'ZSHRC'
		export ZSH=$HOME/.nix-profile/share/oh-my-zsh
		ZSH_THEME="robbyrussell"
		plugins=(git)
		source $ZSH/oh-my-zsh.sh
		source $HOME/.nix-profile/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
		source $HOME/.nix-profile/share/zsh-autosuggestions/zsh-autosuggestions.zsh
		ZSHRC

		  cd "$HOME"
		  export PATH="$HOME/.nix-profile/bin:$PATH"
		  export SHELL="$HOME/.nix-profile/bin/zsh"
		  exec zsh
		else
		  mkdir -p ~/.local/state/nix/profiles

		  echo "Activating cloud-shell home-manager configuration..."
		  nix run home-manager/master -- switch --impure --show-trace \
		    --flake "$FLAKE_URL" -b backup

		  echo "====================================="
		  echo "Welcome to cloud-shell environment!"
		  echo "Configuration: AddG0/nix-config"
		  echo "====================================="

		  # Write SSH_AUTH_SOCK to .zshrc.imperitive so it persists past zsh init
		  if [ -n "$SSH_AUTH_SOCK" ]; then
		    echo "export SSH_AUTH_SOCK=\"$SSH_AUTH_SOCK\"" > ~/.zshrc.imperitive
		  fi

		  cd "$HOME"
		  exec env PATH="$HOME/.nix-profile/bin:$PATH" SHELL="$HOME/.nix-profile/bin/zsh" zsh -l
		fi
	INIT_EOF
}

CLEANUP_DONE=false

cleanup() {
	[[ "$CLEANUP_DONE" == "true" ]] && return 0
	CLEANUP_DONE=true
	trap '' SIGINT SIGTERM

	echo ""
	ssh_agent_cleanup

	# Check if pod is still running
	local pod_status
	pod_status=$(kubectl "${KUBECTL_ARGS[@]}" get pod "$POD_NAME" -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")

	if [[ "$pod_status" == "Running" ]]; then
		# Pod is still running, ask user if they want to keep it
		echo ""
		read -r -p "[cloud-shell] Keep pod running for later? [y/N] " -t 30 response || response="n"
		if [[ "$response" =~ ^[Yy]$ ]]; then
			log "Pod kept running: $POD_NAME"
			log "Reattach with: kubectl-cloud-shell --attach $POD_NAME"
			return 0
		fi
	fi

	log "Deleting pod..."
	kubectl "${KUBECTL_ARGS[@]}" delete pod "$POD_NAME" --ignore-not-found=true --wait=false 2>/dev/null || true
}

run_pod() {
	local overrides init_script
	overrides="$(build_pod_overrides)"
	init_script="$(get_init_script)"

	log "Starting pod $POD_NAME..."
	echo "Type 'exit' to leave. You'll be asked if you want to keep the pod running."

	# Ctrl+C during setup triggers cleanup; disabled once attached to pod
	trap 'exit 130' SIGINT SIGTERM
	trap cleanup EXIT

	kubectl "${KUBECTL_ARGS[@]}" run "$POD_NAME" --restart=Never \
		--image="$POD_IMAGE" \
		--overrides="$overrides"

	log "Waiting for pod to be ready..."
	kubectl "${KUBECTL_ARGS[@]}" wait --for=condition=Ready "pod/$POD_NAME" --timeout=120s

	flake_setup &
	local flake_pid=$!
	copy_setup &
	local copy_pid=$!
	ssh_agent_setup &
	local ssh_pid=$!
	wait "$flake_pid" "$copy_pid" "$ssh_pid"

	trap '' SIGINT SIGTERM
	log "Attaching to pod..."
	kubectl "${KUBECTL_ARGS[@]}" exec -it "$POD_NAME" -- sh -c "$init_script"
}

main() {
	parse_args "$@"

	# Handle --list mode
	if [[ "$LIST_PODS" == "true" ]]; then
		list_pods
		exit 0
	fi

	# Handle --clean mode
	if [[ "$CLEAN_ALL" == "true" ]]; then
		clean_all
		exit 0
	fi

	# Handle --attach mode
	if [[ -n "$ATTACH_POD" ]]; then
		validate
		attach_pod "$ATTACH_POD"
		exit 0
	fi

	# Normal mode: create new pod
	validate
	run_pod
}

main "$@"
