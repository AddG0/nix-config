#!/usr/bin/env bash
set -euo pipefail

# >>> usage
# Bootstrap script for nix + home-manager in ephemeral or foreign environments
# (Google Cloud Shell, Debian/Ubuntu boxes without nix-config, etc.)
#
# Usage:
#   setup-cloud-shell.sh install       # install nix + apply home-manager
#   setup-cloud-shell.sh switch        # just re-apply home-manager
#   setup-cloud-shell.sh uninstall     # remove nix entirely
#   setup-cloud-shell.sh help
#
# Curl-piped:
#   curl -L https://raw.githubusercontent.com/AddG0/nix-config/main/scripts/setup-cloud-shell.sh | bash -s install
#   curl -L https://raw.githubusercontent.com/AddG0/nix-config/main/scripts/setup-cloud-shell.sh | bash -s uninstall
#
# MODE (install only): sudo | rootless. If unset, the script prompts.
# FLAKE_URL: override the flake reference (default: AddG0/nix-config#cloud-shell).
# <<< usage

FLAKE_URL="${FLAKE_URL:-git+https://github.com/AddG0/nix-config?ref=main#cloud-shell}"

# Where we stash the user's pre-install login shell so sudo uninstall can
# restore it before /nix is removed (otherwise next login fails to exec
# the deleted ~/.nix-profile/bin/zsh).
PREV_SHELL_MARKER="$HOME/.local/share/setup-cloud-shell/previous-login-shell"

# The static nix binary is a multicall executable — one ELF, dispatches on
# argv[0]. The classic Nix CLI (nix-env, nix-store, nix-build, …) is what
# most tooling actually invokes (including home-manager's activation script).
# A full tarball install creates these symlinks for us; downloading just the
# single binary means we have to create them ourselves.
NIX_COMMAND_NAMES=(
	nix-build nix-channel nix-collect-garbage nix-copy-closure
	nix-daemon nix-env nix-hash nix-instantiate nix-prefetch-url
	nix-shell nix-store
)

# Inline nix settings every invocation needs, so behavior doesn't depend on
# whatever (or whether) nix.conf exists on disk. Exported so the home-manager
# subprocess that nix run spawns inherits the same settings.
# accept-flake-config=true bypasses the interactive prompt for substituters
# and trusted-keys declared in the flake's nixConfig — trade-off: a malicious
# fork could ship extra caches. Acceptable for a self-controlled config.
export NIX_CONFIG="experimental-features = nix-command flakes
accept-flake-config = true"

#####################################################################
# UI helpers
#####################################################################

# Honor NO_COLOR (https://no-color.org) and disable when not a TTY.
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
	C_RESET=$'\033[0m'
	C_BOLD=$'\033[1m'
	C_DIM=$'\033[2m'
	C_RED=$'\033[31m'
	C_GREEN=$'\033[32m'
	C_YELLOW=$'\033[33m'
	C_BLUE=$'\033[34m'
	C_CYAN=$'\033[36m'
else
	C_RESET="" C_BOLD="" C_DIM="" C_RED="" C_GREEN="" C_YELLOW="" C_BLUE="" C_CYAN=""
fi

# Phase tracking — set by cmd_install / cmd_uninstall before each step.
STEP_NUM=0
STEP_TOTAL=0

banner() {
	printf '\n%s┌─%s %s%s%s %s─┐%s\n' \
		"$C_DIM" "$C_RESET" "$C_BOLD" "$1" "$C_RESET" "$C_DIM" "$C_RESET"
}

step() {
	STEP_NUM=$((STEP_NUM + 1))
	printf '\n%s[%d/%d]%s %s%s%s\n' \
		"$C_CYAN" "$STEP_NUM" "$STEP_TOTAL" "$C_RESET" \
		"$C_BOLD" "$1" "$C_RESET"
}

info() { printf '  %s•%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
success() { printf '  %s✓%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn() { printf '  %s!%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }

# Print an error block with optional remediation. Usage:
#   die "headline" ["remediation line 1" "remediation line 2" ...]
die() {
	local headline="$1"
	shift || true
	printf '\n%s✗ error:%s %s\n' "$C_RED$C_BOLD" "$C_RESET" "$headline" >&2
	if [ "$#" -gt 0 ]; then
		printf '\n%sTo fix:%s\n' "$C_YELLOW" "$C_RESET" >&2
		for line in "$@"; do printf '  %s\n' "$line" >&2; done
	fi
	printf '\n' >&2
	exit 1
}

usage() {
	# Print the >>> usage / <<< usage block at the top of this file, with the
	# leading "# " stripped. Sentinel-based so editing the header doesn't break
	# this function.
	sed -n '/^# >>> usage$/,/^# <<< usage$/{/^# >>> usage$/d;/^# <<< usage$/d;s/^# \?//;p;}' "$0"
	exit "${1:-0}"
}

#####################################################################
# Shared helpers — used by multiple subcommands
#####################################################################

# Returns one of: sudo | rootless | none. Filesystem-based; if both signals
# are present (mixed state) prefers sudo since that's the more invasive one.
detect_install() {
	if [ -e /nix/receipt.json ] || [ -x /nix/nix-installer ]; then
		echo sudo
	elif [ -x "$HOME/.local/bin/nix" ] || [ -d "$HOME/.local/share/nix/root" ]; then
		echo rootless
	else
		echo none
	fi
}

# Append our PATH + auto-enter block to ~/.profile. Rootless-only — sudo
# installs use chsh_to_hm_zsh instead (changing the system login shell is
# cleaner when we have the privileges). Idempotent via marker guard.
# Only touches ~/.profile — home-manager owns ~/.bashrc / ~/.zshrc, so editing
# those either fails (symlinked into the store) or gets clobbered on the next
# switch. ~/.profile is sourced by every login shell and is normally HM-free.
# If ~/.profile is a symlink (managed elsewhere — chezmoi, etc.), skip.
profile_block_install() {
	local rc="$HOME/.profile"
	if [ -L "$rc" ]; then
		warn "~/.profile is a symlink (managed elsewhere) — skipping PATH persistence"
		return
	fi
	if grep -qF '>>> setup-cloud-shell.sh' "$rc" 2>/dev/null; then
		return
	fi
	cat >>"$rc" <<'EOF'

# >>> setup-cloud-shell.sh — do not edit between these markers
export PATH="$HOME/.nix-profile/bin:$HOME/.local/bin:$PATH"
# Auto-enter the rootless Nix user namespace for interactive login shells.
# Interactive-only guard ($- contains 'i') keeps scp/rsync/non-interactive
# `ssh host cmd` working — those reach this rc but skip the exec.
# IN_NIX_NS prevents recursion on re-entry. If exec fails, falls back to
# this shell so you're never locked out.
# NIX_CONFIG inline so this doesn't depend on whatever nix.conf state HM left.
# accept-flake-config bypasses the interactive substituter prompt; safe for a
# self-controlled config but worth knowing if you ever fork-and-share this.
case $- in
  *i*)
    if [ -z "${IN_NIX_NS:-}" ] && [ -x "$HOME/.local/bin/nix" ]; then
      export IN_NIX_NS=1
      export NIX_CONFIG="experimental-features = nix-command flakes
accept-flake-config = true"
      # nix shell -c CMD ARGS does an exec under the hood (verified: the
      # spawned zsh's PPID is sshd directly), so the chain bash→nix-shell→zsh
      # collapses to one process. Single `exit` ends the session.
      exec "$HOME/.local/bin/nix" shell \
        "$HOME/.local/state/nix/profiles/profile" \
        -c "$HOME/.nix-profile/bin/zsh" -l
    fi
    ;;
esac
# <<< setup-cloud-shell.sh
EOF
	info "Added PATH + auto-enter block to ~/.profile"
}

# Remove our ~/.profile block (sentinel-delimited). Safe to call when the
# block isn't present.
profile_block_remove() {
	local rc="$HOME/.profile"
	[ -f "$rc" ] || return 0
	[ ! -L "$rc" ] || return 0
	grep -qF '>>> setup-cloud-shell.sh' "$rc" 2>/dev/null || return 0
	sed -i.bak '/>>> setup-cloud-shell\.sh/,/<<< setup-cloud-shell\.sh/d' "$rc" || true
	info "~/.profile cleaned (backup at ~/.profile.bak)"
}

# Replace the script process with /bin/sh and SIGKILL the script's parent
# (the shell that invoked us). `exec` makes the kill atomic from the
# parent's POV (it sees the foreground job still running, no "jobs killed"
# warning), and SIGKILL is instant — the parent can't redraw its prompt
# or trip broken hooks before dying. Caller never returns.
hangup_parent_shell() {
	exec /bin/sh -c "kill -KILL $PPID 2>/dev/null"
}

# If the calling shell is the now-dismantled HM zsh (parent's exe link still
# references /nix/store/...), close the SSH session so the user reconnects
# to a fresh login shell — which chsh_restore_previous already pointed back
# at their real login shell. Trying to keep them in the same session means
# either leaving the broken zsh as a parent (stale-hook spam) or running an
# orphan bash that loses the session anyway. Just disconnect and let them
# come back clean.
maybe_escape_stale_shell() {
	local parent_exe
	parent_exe=$(readlink "/proc/$PPID/exe" 2>/dev/null || true)
	case "$parent_exe" in
	/nix/store/*)
		printf '%sClosing your shell — reconnect for a clean session.%s\n\n' \
			"$C_YELLOW" "$C_RESET"
		hangup_parent_shell
		;;
	esac
}

# For sudo installs: set the user's login shell to the HM-managed zsh so
# every SSH session lands there directly. Saves the previous shell so
# uninstall can restore it. Idempotent — no-op if already pointing at HM.
chsh_to_hm_zsh() {
	local target="$HOME/.nix-profile/bin/zsh"
	[ -x "$target" ] || return 0
	local current_shell
	current_shell="$(getent passwd "$USER" | cut -d: -f7)"
	[ "$current_shell" = "$target" ] && return 0

	info "Setting login shell to HM zsh..."
	mkdir -p "$(dirname "$PREV_SHELL_MARKER")"
	echo "$current_shell" >"$PREV_SHELL_MARKER"
	# chsh refuses shells not in /etc/shells; add ours if missing.
	if ! grep -qxF "$target" /etc/shells; then
		echo "$target" | sudo tee -a /etc/shells >/dev/null
	fi
	sudo chsh -s "$target" "$USER"
	success "Login shell changed to HM zsh"
}

# Inverse of chsh_to_hm_zsh. Must run before /nix is removed.
chsh_restore_previous() {
	[ -f "$PREV_SHELL_MARKER" ] || return 0
	local previous_shell
	previous_shell="$(cat "$PREV_SHELL_MARKER")"
	if [ -x "$previous_shell" ]; then
		info "Restoring login shell to $previous_shell..."
		sudo chsh -s "$previous_shell" "$USER"
	fi
	# Strip the HM zsh path from /etc/shells. Use # as sed delimiter so
	# / in the home directory path doesn't conflict.
	sudo sed -i.bak "\\#^$HOME/\\.nix-profile/bin/zsh\$#d" /etc/shells || true
	rm -f "$PREV_SHELL_MARKER"
	rmdir "$(dirname "$PREV_SHELL_MARKER")" 2>/dev/null || true
}

#####################################################################
# Dependency / environment checks
#####################################################################

require_cmd() {
	command -v "$1" &>/dev/null || die \
		"missing required command: $1" \
		"Install it via your distro's package manager, e.g.:" \
		"  Debian/Ubuntu:  sudo apt install -y $1" \
		"  Fedora/RHEL:    sudo dnf install -y $1" \
		"  Arch:           sudo pacman -S $1"
}

check_deps_common() {
	require_cmd curl
	require_cmd git
}

check_sudo() {
	command -v sudo &>/dev/null || die \
		"sudo mode requested but sudo is not installed" \
		"Either install sudo, or re-run with MODE=rootless."
	sudo -v || die \
		"sudo mode requested but you can't sudo on this host" \
		"Either get sudo access, or re-run with MODE=rootless."
}

check_userns() {
	require_cmd unshare
	if ! [ -r /proc/sys/kernel/unprivileged_userns_clone ] ||
		[ "$(cat /proc/sys/kernel/unprivileged_userns_clone)" != "1" ]; then
		die "rootless mode requires unprivileged user namespaces (disabled in kernel)" \
			"Enable with: sudo sysctl -w kernel.unprivileged_userns_clone=1"
	fi
	if ! unshare -Ur true 2>/dev/null; then
		if [ -r /proc/sys/kernel/apparmor_restrict_unprivileged_userns ] &&
			[ "$(cat /proc/sys/kernel/apparmor_restrict_unprivileged_userns)" = "1" ]; then
			die "rootless mode blocked by AppArmor (Ubuntu 23.10+ default)" \
				"Temporarily:   sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0" \
				"Persistently:  echo 'kernel.apparmor_restrict_unprivileged_userns=0' \\" \
				"                 | sudo tee /etc/sysctl.d/60-apparmor-userns.conf"
		fi
		die "rootless mode requires unprivileged user namespaces (unshare test failed)"
	fi
}

#####################################################################
# Install
#####################################################################

prompt_mode() {
	# Read from /dev/tty so this works under `curl ... | bash -s install`,
	# where stdin is the script body — `read` against that gets nothing.
	[ -r /dev/tty ] || die "no TTY available — set MODE=sudo or MODE=rootless explicitly"
	printf '\n%sChoose install mode:%s\n' "$C_BOLD" "$C_RESET"
	printf '  %s1)%s %ssudo%s     — Determinate installer, multi-user daemon, /nix at root\n' \
		"$C_CYAN" "$C_RESET" "$C_BOLD" "$C_RESET"
	printf '  %s2)%s %srootless%s — static binary, chroot store at ~/.local/share/nix/root\n' \
		"$C_CYAN" "$C_RESET" "$C_BOLD" "$C_RESET"
	read -rp "$(printf '%sMode%s [1/2]: ' "$C_BOLD" "$C_RESET")" choice </dev/tty
	case "$choice" in
	1) MODE=sudo ;;
	2) MODE=rootless ;;
	*) die "invalid choice: $choice" ;;
	esac
}

install_nix_sudo() {
	check_sudo
	info "Running the Determinate Systems installer (this can take a minute)..."
	# `--init none` only on systems where systemd isn't PID 1 (Cloud Shell,
	# WSL without systemd, containers). On systemd hosts the default planner
	# installs the nix-daemon unit so the multi-user store actually works
	# without us managing process lifecycle by hand.
	local init_args=()
	[ -d /run/systemd/system ] || init_args=(--init none)
	curl -fsSL https://install.determinate.systems/nix |
		sh -s -- install linux --no-confirm "${init_args[@]}"
	. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
	success "Nix installed at /nix (multi-user daemon)"
}

install_nix_rootless() {
	check_userns
	info "Downloading static Nix binary..."
	mkdir -p "$HOME/.local/bin" "$HOME/.local/state/nix/profiles"
	# Download to a temp file then atomically rename. Prevents a Ctrl-C'd
	# download from leaving a corrupt ~/.local/bin/nix that subsequent runs
	# would skip past (because `command -v nix` sees a file and assumes good).
	local tmp_nix
	tmp_nix="$(mktemp "$HOME/.local/bin/.nix.XXXXXX")"
	trap 'rm -f "$tmp_nix"' RETURN
	curl -fsSL https://hydra.nixos.org/job/nix/master/buildStatic.x86_64-linux/latest/download-by-type/file/binary-dist \
		-o "$tmp_nix"
	chmod +x "$tmp_nix"
	mv "$tmp_nix" "$HOME/.local/bin/nix"
	trap - RETURN
	for cmd in "${NIX_COMMAND_NAMES[@]}"; do
		ln -sf "$HOME/.local/bin/nix" "$HOME/.local/bin/$cmd"
	done
	# ~/.nix-profile is the conventional path every Nix-aware tool expects
	# (home-manager session vars, oh-my-zsh, command-not-found, etc.). Rootless
	# mode stores the actual profile at ~/.local/state/nix/profiles/profile/
	# and doesn't create the conventional symlink — so we do.
	ln -s "$HOME/.local/state/nix/profiles/profile" "$HOME/.nix-profile"
	# No nix.conf write: the script uses NIX_CONFIG (set at top) for its own
	# invocations, and HM activation produces the real ~/.config/nix/nix.conf
	# immediately after via `nix.settings` in home/common/core/nix.nix.
	export PATH="$HOME/.local/bin:$PATH"
	profile_block_install
	success "Rootless Nix installed (store at ~/.local/share/nix/root)"
}

cmd_install() {
	banner "Bootstrap: nix + home-manager"

	if command -v nix &>/dev/null; then
		STEP_TOTAL=1
		info "Nix already installed at $(command -v nix) — skipping install."
	else
		STEP_TOTAL=3
		step "Verifying dependencies"
		check_deps_common
		success "curl + git present"

		MODE="${MODE:-}"
		if [ -z "$MODE" ]; then
			prompt_mode
		else
			info "MODE=$MODE (from env)"
		fi

		step "Installing Nix ($MODE mode)"
		case "$MODE" in
		sudo) install_nix_sudo ;;
		rootless) install_nix_rootless ;;
		*) die "MODE must be 'sudo' or 'rootless', got: $MODE" ;;
		esac
	fi

	step "Applying home-manager configuration"
	info "Flake: $FLAKE_URL"
	run_switch

	# Sudo: chsh handles future logins; for the current session we `exec` into
	# zsh so the script process IS replaced by zsh (no waiting parent bash —
	# avoids "Killed ..." noise if user later runs uninstall from that zsh).
	# Trade-off: when user exits this zsh they're back in the original login
	# bash, one more `exit` (or reconnect) closes SSH.
	# Rootless: chsh isn't available; we must enter the namespace from the
	# script. drop_into_zsh wraps that and runs zsh as a child to set up
	# parent-kill for single-exit UX.
	case "${MODE:-$(detect_install)}" in
	sudo)
		chsh_to_hm_zsh
		printf '\n%s✓ All set.%s Dropping you into zsh now.\n\n' "$C_GREEN$C_BOLD" "$C_RESET"
		export PATH="$HOME/.nix-profile/bin:$PATH"
		export SHELL="$HOME/.nix-profile/bin/zsh"
		exec "$HOME/.nix-profile/bin/zsh" -l
		;;
	*)
		printf '\n%s✓ All set.%s Dropping you into zsh now.\n\n' "$C_GREEN$C_BOLD" "$C_RESET"
		drop_into_zsh
		;;
	esac
}

# Drop the user into their HM-managed zsh. Path differs by install mode:
#  - sudo install: /nix is real, ~/.nix-profile/bin/zsh resolves directly.
#  - rootless install: /nix/store is only mounted inside the user namespace,
#    so we re-enter it via `nix shell` to make the profile reachable.
# After zsh exits, kill the parent (user's login bash) so the SSH session
# ends on a single `exit`. Without this, exec only replaces the script's
# own shell — the login bash stays up the chain and the user has to exit
# twice. Future SSH logins don't hit this because the ~/.profile auto-enter
# runs in the login bash directly, so its exec really does replace the
# login shell.
drop_into_zsh() {
	local zsh="$HOME/.nix-profile/bin/zsh"
	export SHELL="$zsh"

	# MODE may be unset if install was skipped; fall back to detection.
	# `|| true` on each launch so zsh exiting non-zero (Ctrl-C → 130, errors)
	# doesn't trip set -e and skip the parent-shell cleanup below.
	case "${MODE:-$(detect_install)}" in
	rootless)
		nix shell "$HOME/.local/state/nix/profiles/profile" -c "$zsh" -l || true
		;;
	sudo)
		# PATH prepend so HM-installed CLIs reach commands the zsh init may
		# invoke before hm-session-vars sources.
		export PATH="$HOME/.nix-profile/bin:$PATH"
		"$zsh" -l || true
		;;
	*)
		die "no nix install detected after activation — something went wrong"
		;;
	esac
	# zsh exited — end the SSH session cleanly so the user only has to type
	# `exit` once. Future SSH logins skip this code path entirely (auto-enter
	# happens in the login shell directly, no script-wrapper to escape).
	hangup_parent_shell
}

#####################################################################
# Switch (re-apply home-manager only)
#####################################################################

# Shared by cmd_install and cmd_switch.
run_switch() {
	command -v nix &>/dev/null || die "nix not on PATH — run '$0 install' first"
	# Refresh only the top-level flake URL so freshly pushed commits on the
	# tracked ref are picked up. Bypasses cache for THIS url only — lazy-trees
	# keeps every other input cached at its lock-file rev, so unreachable
	# private inputs aren't probed.
	nix flake metadata --refresh "$FLAKE_URL" >/dev/null 2>&1 || true
	nix run home-manager/master -- \
		switch --impure --flake "$FLAKE_URL" -b backup
	success "home-manager generation activated"
}

cmd_switch() {
	banner "Re-applying home-manager"
	STEP_TOTAL=1
	step "Activating configuration"
	info "Flake: $FLAKE_URL"
	run_switch
	printf '\n%s✓ Done.%s\n\n' "$C_GREEN$C_BOLD" "$C_RESET"
}

#####################################################################
# Uninstall
#####################################################################

uninstall_sudo() {
	check_sudo
	# Restore previous login shell BEFORE removing /nix, otherwise the next
	# login fails trying to exec the deleted ~/.nix-profile/bin/zsh.
	chsh_restore_previous
	info "Running Determinate uninstaller..."
	if [ -x /nix/nix-installer ]; then
		sudo /nix/nix-installer uninstall --no-confirm
		# Determinate doesn't touch the user-side symlinks. Clean them up so
		# a later rootless reinstall doesn't trip on dangling ~/.nix-profile.
		rm -rf "$HOME/.nix-profile" "$HOME/.nix-channels" "$HOME/.nix-defexpr"
		success "/nix removed; daemon stopped"
	else
		die "expected /nix/nix-installer to exist" \
			"Uninstall manually following https://nix.dev/manual/nix/2.24/installation/uninstall"
	fi
}

uninstall_rootless() {
	info "Removing rootless Nix..."
	rm -f "$HOME/.local/bin/nix"
	for cmd in "${NIX_COMMAND_NAMES[@]}"; do
		rm -f "$HOME/.local/bin/$cmd"
	done
	# Store paths are read-only; restore write perms before rm. || true so a
	# single locked file doesn't abort the whole uninstall under set -e.
	[ -d "$HOME/.local/share/nix" ] && chmod -R u+w "$HOME/.local/share/nix" || true
	rm -rf "$HOME/.local/share/nix"
	rm -rf "$HOME/.local/state/nix"
	rm -rf "$HOME/.cache/nix"
	rm -rf "$HOME/.config/nix"
	rm -rf "$HOME/.nix-profile" "$HOME/.nix-channels" "$HOME/.nix-defexpr"
	profile_block_remove
	success "Rootless Nix removed"
}

uninstall_home_manager() {
	# Clean up HM-managed symlinks before removing the store. Best-effort.
	# home-manager uninstall is interactive — feed it 'y' to skip the prompt.
	if command -v home-manager &>/dev/null; then
		info "Removing home-manager generations..."
		yes 2>/dev/null | home-manager uninstall 2>/dev/null || true
	fi
	rm -rf "$HOME/.local/state/home-manager"
}

cmd_uninstall() {
	banner "Uninstall: nix + home-manager"

	# Uninstall tears down the very profile that put many of our coreutils on
	# PATH (~/.nix-profile/bin/{rm,chmod,grep,sed,...}). Once HM uninstall
	# removes that profile, dangling symlinks would break the rest of this
	# function. Reset PATH to system defaults so we always use real binaries.
	PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

	local kind
	kind="$(detect_install)"
	if [ "$kind" = "none" ]; then
		die "no Nix installation detected"
	fi

	STEP_TOTAL=2
	step "Removing home-manager generations"
	uninstall_home_manager
	success "home-manager cleaned up"

	step "Removing Nix ($kind install)"
	case "$kind" in
	sudo) uninstall_sudo ;;
	rootless) uninstall_rootless ;;
	esac

	printf '\n%s✓ Uninstall complete.%s' "$C_GREEN$C_BOLD" "$C_RESET"
	printf ' You may also want to %srm -rf ~/nix-config%s if cloned.\n\n' "$C_BOLD" "$C_RESET"

	maybe_escape_stale_shell
}

#####################################################################
# Dispatch
#####################################################################

cmd="${1:-}"
case "$cmd" in
install) cmd_install ;;
switch) cmd_switch ;;
uninstall) cmd_uninstall ;;
help | -h | --help) usage 0 ;;
"") usage 1 ;;
*) die "unknown subcommand: $cmd (try: install | switch | uninstall | help)" ;;
esac
