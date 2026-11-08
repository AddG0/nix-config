# git-sync's run: locks the remote flake, verifies its signature, activates it, then reboots or rolls back as configured.
{
  lib,
  writeShellApplication,
  coreutils,
  gawk,
  git,
  iputils,
  jq,
  libnotify,
  nix,
  nixos-rebuild,
  openssh,
  sudo,
  systemd,
  util-linux,
  cfg,
  hostName,
  waitForNetwork,
  lastBuiltRecord,
  allowedSignersFile,
  verifySignature,
  needsReboot,
}: let
  checksSignature = cfg.allowedSigners != [];

  notifyFunction =
    if cfg.notifications.enable
    then ''
      # Best effort, to notifyUser's first loginctl session: a failure must not stop a restore or reboot.
      notify() {
        for session in $(loginctl list-sessions --no-legend | awk '{print $1}'); do
          user=$(loginctl show-session "$session" -p Name --value) || continue
          if [ "$user" = "${cfg.notifications.notifyUser}" ]; then
            uid=$(loginctl show-session "$session" -p User --value) || continue
            display=$(loginctl show-session "$session" -p Display --value || echo ":0")
            sudo -u "${cfg.notifications.notifyUser}" \
              DISPLAY="$display" \
              DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
              notify-send "$@" || log "WARNING: Could not notify ${cfg.notifications.notifyUser} (exit $?)."
            break
          fi
        done
      }
    ''
    else ''
      notify() { :; }
    '';

  verifySignatureFunction = ''
    verify_signature() {
      local git_url rev verdict
      git_url=$(jq -r -f ${./locked-git-url.jq} <<<"$METADATA")
      rev=$(jq -r '.locked.rev // empty' <<<"$METADATA")
      if ! verdict=$(${verifySignature} ${allowedSignersFile} "$git_url" "$rev"); then
        verdict=''${verdict:-The signature check failed without saying why.}
        log "ERROR: $verdict Refusing to rebuild."
        notify -u critical "NixOS Remote Rebuild" "Refused to rebuild from $LOCKED_URL: $verdict"
        exit 1
      fi
      log "$verdict"
    }
  '';

  # switch would restart services on the new userspace under the old kernel; boot leaves the whole change to the next boot.
  deferKernelChange = lib.optionalString (cfg.rebuildCommand == "switch") ''
    if ${needsReboot} "$WORK_DIR/system"; then
      log "Activating at the next boot, so nothing restarts under the old kernel."
      ACTION=boot
    fi
  '';

  preRebuildStep = lib.optionalString (cfg.preRebuildHook != "") ''
    log "Running pre-rebuild hook..."
    ${cfg.preRebuildHook}
  '';

  postRebuildStep = lib.optionalString (cfg.postRebuildHook != "") ''
    log "Running post-rebuild hook..."
    ${cfg.postRebuildHook}
  '';

  preRebootStep = lib.optionalString (cfg.preRebootHook != "") ''
    log "Running pre-reboot hook..."
    (${cfg.preRebootHook}) || log "WARNING: pre-reboot hook failed (exit $?); rebooting anyway."
  '';

  rebootNow =
    if cfg.notifications.enable
    then ''
      log "Scheduling reboot in 2 minutes..."
      notify -u critical "NixOS Remote Rebuild" "Configuration updated. Rebooting in 2 minutes. Run 'sudo shutdown -c' to cancel."
      shutdown --reboot +2 "NixOS remote rebuild complete. Rebooting in 2 minutes. Run 'sudo shutdown -c' to cancel."
    ''
    else ''
      log "Rebooting now..."
      systemctl reboot
    '';

  rebootFunction = lib.optionalString (cfg.reboot != "never") ''
    reboot_host() {
      ${preRebootStep}
      ${rebootNow}
    }
  '';

  # The step after_success ends with, for each value of the reboot option.
  rebootWhenDone = {
    # Only switch defers: boot always waits for a reboot, and test never survives one.
    never = lib.optionalString (cfg.rebuildCommand == "switch") ''
      if ${needsReboot} "$WORK_DIR/system" >/dev/null; then
        log "WARNING: This update changes the kernel, initrd or kernel modules, so it waits for the next reboot."
        notify -u critical "NixOS Remote Rebuild" "Reboot to apply the update: it changes the kernel, initrd or kernel modules."
      fi
    '';
    always = "reboot_host";
    onKernelChange = ''
      if ${needsReboot} "$WORK_DIR/system" >/dev/null; then
        log "Kernel, initrd or modules changed."
        reboot_host
      else
        log "Userspace-only update; no reboot needed."
      fi
    '';
  };

  # Read before activating changes them.
  rememberReplacedSystems = lib.optionalString cfg.autoRollback ''
    RUNNING_SYSTEM=$(readlink -f "''${CURRENT_SYSTEM:-/run/current-system}")
    NEXT_BOOT_SYSTEM=$(readlink -f "''${SYSTEM_PROFILE:-/nix/var/nix/profiles/system}")
  '';

  # Puts back what ACTION changed: switch and test change the running system, switch and boot the next boot's.
  restoreStep = lib.optionalString cfg.autoRollback ''
    restored=true
    if [ "$ACTION" != boot ]; then
      log "Re-activating the running system $RUNNING_SYSTEM..."
      activate test --store-path "$RUNNING_SYSTEM" || {
        log "ERROR: Could not re-activate $RUNNING_SYSTEM (exit $?)."
        restored=false
      }
    fi
    if [ "$ACTION" != test ]; then
      log "Setting the next boot back to $NEXT_BOOT_SYSTEM..."
      activate boot --store-path "$NEXT_BOOT_SYSTEM" || {
        log "ERROR: Could not set the next boot back to $NEXT_BOOT_SYSTEM (exit $?)."
        restored=false
      }
    fi
    if $restored; then
      log "Restored the previous system."
      notify -u normal "NixOS Remote Rebuild" "Restored the previous system"
    else
      notify -u critical "NixOS Remote Rebuild" "Could not restore the previous system. Check logs."
    fi
  '';
in
  writeShellApplication {
    name = "nix-remote-rebuild";
    runtimeInputs =
      [coreutils gawk git iputils jq nix nixos-rebuild openssh systemd util-linux]
      ++ lib.optionals cfg.notifications.enable [libnotify sudo];
    text = ''
      log() {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
        logger -t nix-remote-rebuild -- "$*"
      }

      ${notifyFunction}

      # Builds from the exact locked revision, so the recorded hash matches what was deployed.
      lock_remote() {
        METADATA=$(nix flake metadata "${cfg.flakeRef}" --refresh --json)
        LOCKED_URL=$(jq -r '.url' <<<"$METADATA")
        LOCKED_NARHASH=$(jq -r '.locked.narHash' <<<"$METADATA")
      }

      ${lib.optionalString checksSignature verifySignatureFunction}

      build() {
        # The out-link keeps the built system from GC until nixos-rebuild adds it to the profile.
        nix build --out-link "$WORK_DIR/system" \
          "$LOCKED_URL#nixosConfigurations.\"${hostName}\".config.system.build.toplevel"
      }

      # Broken in switch-to-configuration's sense: failed, or a service restarting after a non-zero exit.
      broken_units() {
        local unit exit_status
        {
          systemctl list-units --state=failed --plain --no-legend | awk '{print $1}'
          systemctl list-units --type=service --state=auto-restart --plain --no-legend | awk '{print $1}' |
            while read -r unit; do
              if exit_status=$(systemctl show -p ExecMainStatus --value "$unit") && [ -n "$exit_status" ] && [ "$exit_status" != 0 ]; then
                echo "$unit"
              fi
            done
        } | sort -u
      }

      # True when the activation's exit 4 names only units broken before this run, and no other exit-4 cause.
      only_already_broken_units_failed() {
        local reported
        reported=$(sed -n 's/^warning: the following units failed: //p' "$WORK_DIR/activation.log" | tr ',' '\n' | tr -d ' ' | sed '/^$/d' | sort)
        [ -n "$reported" ] || return 1
        if grep -qE '^(Failed to |Unable to |warning: user activation |warning: failed to stat )' "$WORK_DIR/activation.log"; then
          return 1
        fi
        [ -z "$(comm -23 <(printf '%s\n' "$reported") <(printf '%s\n' "$BROKEN_BEFORE"))" ]
      }

      # Runs nixos-rebuild "$@"; an exit 4 that only already-broken units explain counts as success.
      activate() {
        local status=0
        nixos-rebuild "$@" 2>&1 | tee "$WORK_DIR/activation.log" | tee -a "$WORK_DIR/rebuild.log" || status=''${PIPESTATUS[0]}
        if [ "$status" = 4 ] && only_already_broken_units_failed; then
          log "WARNING: Activated; the only failed units were already broken before this run."
          status=0
        fi
        return "$status"
      }

      # Sets ACTION to rebuildCommand, or to boot when switch would restart services under the old kernel.
      choose_action() {
        ACTION=${cfg.rebuildCommand}
        ${deferKernelChange}
      }

      ${rebootFunction}

      after_success() {
        log "Rebuild successful!"
        notify -u normal "NixOS Remote Rebuild" "Configuration updated successfully!"
        ${postRebuildStep}
        ${rebootWhenDone.${cfg.reboot}}
        # Last, so a failed hook or reboot leaves this remote for the next run to retry.
        echo "$LOCKED_NARHASH" >"${lastBuiltRecord}"
      }

      # $1 names the step that failed, $2 is its exit code.
      report_failure() {
        log "ERROR: $1 failed (exit code $2)!"
        log "--- rebuild output (last 30 lines) ---"
        tail -30 "$WORK_DIR/rebuild.log" | while IFS= read -r line; do
          log "  $line"
        done
        log "--- end rebuild output ---"
        notify -u critical "NixOS Remote Rebuild" "$1 FAILED! Check logs."
      }

      # The run
      ${waitForNetwork}
      ${preRebuildStep}
      lock_remote
      ${lib.optionalString checksSignature "verify_signature"}

      log "Rebuilding from $LOCKED_URL#${hostName}..."
      notify -u normal "NixOS Remote Rebuild" "Rebuilding from ${cfg.flakeRef}#${hostName}..."
      WORK_DIR=$(mktemp -d -t nix-remote-rebuild-XXXXXX)
      trap 'rm -rf "$WORK_DIR"' EXIT

      # A failed build changed nothing, so there is nothing to restore.
      if ! build 2>&1 | tee "$WORK_DIR/rebuild.log"; then
        report_failure Build "''${PIPESTATUS[0]}"
        exit 1
      fi

      choose_action
      ${rememberReplacedSystems}
      BROKEN_BEFORE=$(broken_units) || {
        log "ERROR: Could not list broken units before activating (exit $?)."
        exit 1
      }
      status=0
      activate "$ACTION" --store-path "$WORK_DIR/system" || status=$?
      if [ "$status" != 0 ]; then
        report_failure Activation "$status"
        ${restoreStep}
        exit 1
      fi
      after_success
    '';
  }
