#!/bin/bash
set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================

POD_NAME="nix-cloud-shell-$(date +%s)"
POD_IMAGE="nixos/nix:latest"
POD_HOME="/home/addg"
POD_TIMEOUT=21600 # 6 hours

# Feature flags
BARE_MODE=false
COPY_LOCAL=""
COPY_REMOTE="$POD_HOME/workspace"
SSH_AGENT=false
SSH_AGENT_SOCK="/tmp/ssh-agent.sock"

# Resource limits
MEMORY_REQUEST="512Mi"
MEMORY_LIMIT="4Gi"
CPU_REQUEST="250m"
CPU_LIMIT="2"
EPHEMERAL_STORAGE="10Gi"

# Kubectl passthrough args
KUBECTL_ARGS=()

# Extra packages to install in bare mode
BARE_NIX_PACKAGES=(
	"iputils"
	"bind"
)

# =============================================================================
# Helper Functions
# =============================================================================

log() { echo "[cloud-shell] $*"; }
log_error() { echo "[cloud-shell] ERROR: $*" >&2; }

usage() {
	cat <<-EOF
		Usage: kubectl-cloud-shell [OPTIONS] [-- KUBECTL_ARGS...]

		Options:
		  --bare              Use minimal shell without home-manager
		  --copy <dir>        Copy local directory to pod at startup
		  --ssh-agent         Forward local SSH agent to pod
		  --memory <size>     Memory request/limit (default: ${MEMORY_REQUEST}/${MEMORY_LIMIT})
		  --cpu <cores>       CPU request/limit (default: ${CPU_REQUEST}/${CPU_LIMIT})
		  --storage <size>    Ephemeral storage (default: ${EPHEMERAL_STORAGE})
		  --help              Show this help message

		Examples:
		  kubectl-cloud-shell
		  kubectl-cloud-shell --bare
		  kubectl-cloud-shell --copy ~/projects/myapp
		  kubectl-cloud-shell --ssh-agent --copy . -- -n my-namespace
		  kubectl-cloud-shell --memory 1Gi --cpu 1
	EOF
}

# =============================================================================
# Argument Parsing
# =============================================================================

parse_args() {
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--bare)
			BARE_MODE=true
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

# =============================================================================
# Validation
# =============================================================================

validate() {
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

# =============================================================================
# Feature: Copy Local Directory
# =============================================================================

copy_setup() {
	[[ -z "$COPY_LOCAL" ]] && return 0

	log "Copying $COPY_LOCAL -> $POD_NAME:$COPY_REMOTE"
	kubectl "${KUBECTL_ARGS[@]}" cp "$COPY_LOCAL" "$POD_NAME:$COPY_REMOTE"
}

# =============================================================================
# Feature: SSH Agent Forwarding
# =============================================================================

# Uses kubectl exec as transport - no port-forward needed
# Data flow: Pod Unix socket -> kubectl exec stdin/stdout -> local SSH_AUTH_SOCK

SSH_TUNNEL_PID=""

ssh_agent_setup() {
	[[ "$SSH_AGENT" != "true" ]] && return 0

	log "Setting up SSH agent forwarding via kubectl exec..."

	# In bare mode, copy git config and ssh known_hosts
	if [[ "$BARE_MODE" == "true" ]]; then
		log "Copying git and ssh config to pod..."
		kubectl "${KUBECTL_ARGS[@]}" cp "$HOME/.config/git/config" "$POD_NAME:$POD_HOME/.gitconfig"
		kubectl "${KUBECTL_ARGS[@]}" exec "$POD_NAME" -- mkdir -p "$POD_HOME/.ssh"
		[[ -f "$HOME/.ssh/known_hosts" ]] && kubectl "${KUBECTL_ARGS[@]}" cp "$HOME/.ssh/known_hosts" "$POD_NAME:$POD_HOME/.ssh/known_hosts"
	fi

	# Build kubectl command for socat EXEC
	local kubectl_cmd="kubectl"
	if [[ ${#KUBECTL_ARGS[@]} -gt 0 ]]; then
		kubectl_cmd="kubectl ${KUBECTL_ARGS[*]}"
	fi

	# Start tunnel: pod's Unix socket <-> kubectl exec stdio <-> local SSH_AUTH_SOCK
	# The pod socat listens on Unix socket, local socat connects to SSH_AUTH_SOCK
	# Use 'nix run' to avoid install step and PATH issues
	# Escape colons with backslash for socat address parsing
	# Use two --extra-experimental-features flags to avoid quoting issues
	local tunnel_log="/tmp/cloud-shell-tunnel-$$.log"
	log "Starting SSH tunnel (log: $tunnel_log)"
	socat \
		"EXEC:$kubectl_cmd exec -i $POD_NAME -- nix --extra-experimental-features nix-command --extra-experimental-features flakes run nixpkgs\#socat -- UNIX-LISTEN\:${SSH_AGENT_SOCK} STDIO" \
		"UNIX:$SSH_AUTH_SOCK" 2>"$tunnel_log" &
	SSH_TUNNEL_PID=$!

	# Wait for socket to be created (poll instead of fixed sleep)
	log "Waiting for SSH agent socket..."
	for _ in {1..60}; do
		if kubectl "${KUBECTL_ARGS[@]}" exec "$POD_NAME" -- test -S "$SSH_AGENT_SOCK" 2>/dev/null; then
			log "SSH agent forwarding active (socket: $SSH_AGENT_SOCK)"
			return 0
		fi
		if ! kill -0 "$SSH_TUNNEL_PID" 2>/dev/null; then
			log_error "SSH agent tunnel failed to start. Log:"
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

# =============================================================================
# Pod Management
# =============================================================================

build_pod_overrides() {
	# Build environment variables array
	local env_json='[
		{"name": "HOME", "value": "'"$POD_HOME"'"},
		{"name": "USER", "value": "addg"},
		{"name": "BARE_MODE", "value": "'"$BARE_MODE"'"},
		{"name": "BARE_PACKAGES_STR", "value": "'"${BARE_NIX_PACKAGES[*]}"'"}'

	if [[ "$SSH_AGENT" == "true" ]]; then
		env_json="$env_json"',
		{"name": "SSH_AUTH_SOCK", "value": "'"$SSH_AGENT_SOCK"'"}'
	fi
	env_json="$env_json]"

	local overrides='{
		"spec": {
			"activeDeadlineSeconds": '"$POD_TIMEOUT"',
			"containers": [{
				"name": "'"$POD_NAME"'",
				"image": "'"$POD_IMAGE"'",
				"command": ["sh", "-c", "mkdir -p '"$COPY_REMOTE"' && sleep infinity"],
				"env": '"$env_json"',
				"resources": {
					"requests": {
						"memory": "'"$MEMORY_REQUEST"'",
						"cpu": "'"$CPU_REQUEST"'",
						"ephemeral-storage": "'"$EPHEMERAL_STORAGE"'"
					},
					"limits": {
						"memory": "'"$MEMORY_LIMIT"'",
						"cpu": "'"$CPU_LIMIT"'",
						"ephemeral-storage": "'"$EPHEMERAL_STORAGE"'"
					}
				}
			}]
		}
	}'
	echo "$overrides"
}

get_init_script() {
	cat <<-'INIT_EOF'
		set -e

		# Enable flakes and nix-command
		mkdir -p ~/.config/nix
		{
		  echo 'experimental-features = nix-command flakes'
		  echo 'accept-flake-config = true'
		  echo 'max-jobs = 4'
		  echo 'cores = 4'
		} > ~/.config/nix/nix.conf

		if [ "$BARE_MODE" = "true" ]; then
		  echo "====================================="
		  echo "Bare Nix Shell (zsh + oh-my-zsh)"
		  echo "====================================="

		  # Build package list - base packages plus extras from BARE_PACKAGES_STR
		  # Note: glibc provides iconv command needed by oh-my-zsh
		  PKGS="nixpkgs#{zsh,oh-my-zsh,zsh-syntax-highlighting,zsh-autosuggestions,glibc,coreutils}"
		  for pkg in $BARE_PACKAGES_STR; do
		    PKGS="$PKGS nixpkgs#$pkg"
		  done
		  eval "nix profile add $PKGS"

		  # Set up zshrc
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
		    --flake "git+https://github.com/AddG0/nix-config?ref=main#cloud-shell" -b backup

		  echo "====================================="
		  echo "Welcome to cloud-shell environment!"
		  echo "Configuration: AddG0/nix-config"
		  echo "====================================="

		  cd "$HOME"
		  exec env PATH="$HOME/.nix-profile/bin:$PATH" SHELL="$HOME/.nix-profile/bin/zsh" zsh -l
		fi
	INIT_EOF
}

CLEANUP_DONE=false

cleanup() {
	# Prevent double cleanup (EXIT trap fires after interrupt handler)
	[[ "$CLEANUP_DONE" == "true" ]] && return 0
	CLEANUP_DONE=true

	# Ignore interrupts during cleanup
	trap '' SIGINT SIGTERM

	echo ""
	log "Cleaning up..."
	ssh_agent_cleanup
	# Add more cleanup hooks here as features are added
	log "Deleting pod..."
	kubectl "${KUBECTL_ARGS[@]}" delete pod "$POD_NAME" --ignore-not-found=true --wait=false 2>/dev/null || true
}

run_pod() {
	local overrides
	overrides="$(build_pod_overrides)"

	local init_script
	init_script="$(get_init_script)"

	log "Starting pod $POD_NAME..."
	echo "Type 'exit' to leave the pod. The pod will be deleted automatically."

	# Allow Ctrl+C during setup (triggers exit -> cleanup)
	trap 'exit 130' SIGINT SIGTERM
	trap cleanup EXIT

	# Start pod in detached mode
	kubectl "${KUBECTL_ARGS[@]}" run "$POD_NAME" --restart=Never \
		--image="$POD_IMAGE" \
		--overrides="$overrides"

	log "Waiting for pod to be ready..."
	kubectl "${KUBECTL_ARGS[@]}" wait --for=condition=Ready "pod/$POD_NAME" --timeout=120s

	# Run feature setup hooks in parallel
	copy_setup &
	local copy_pid=$!
	ssh_agent_setup &
	local ssh_pid=$!

	# Wait for setup to complete
	wait "$copy_pid" "$ssh_pid"

	# Disable Ctrl+C handling - it now goes to the pod shell
	trap '' SIGINT SIGTERM

	log "Attaching to pod..."
	kubectl "${KUBECTL_ARGS[@]}" exec -it "$POD_NAME" -- sh -c "$init_script"
}

# =============================================================================
# Main
# =============================================================================

main() {
	parse_args "$@"
	validate
	run_pod
}

main "$@"
