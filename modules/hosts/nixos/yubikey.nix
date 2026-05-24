# Yubikey support: pcscd + udev rules + FIDO U2F PAM for sudo/login.
# Optional behaviors gated per-host:
#   - autoScreenActivate: wake the screen on insert (no auth bypass)
#   - autoScreenUnlock:   bypass hyprlock on insert + tap (cryptographic)
#   - autoScreenLock:     lock all sessions on removal
#
# ─── One-time setup per physical key (not managed by Nix) ──────────────────
#
# Disable the OTP application on USB. New yubikeys ship with slot 1 holding a
# Yubico OTP credential; the touch contact is right where your fingers land
# when inserting the key, so a brushed contact emits a string like
# "cccccdfcuvjib..." into whatever has keyboard focus (terminal, login field,
# anywhere). Yubico OTP is legacy — FIDO2/WebAuthn replaces it everywhere we
# use the key. Disable per key:
#
#   ykman config usb --disable OTP
#   ykman info   # confirm OTP is no longer listed under "Enabled USB interfaces"
#
# Set the FIDO2 PIN (required by 1Password to register the key as a 2FA factor):
#
#   ykman fido access change-pin
#
# ─── One-time setup per host (not managed by Nix) ──────────────────────────
#
# Enroll keys for PAM U2F so sudo/login prompt for a tap instead of a password:
#
#   yubikey-enroll   # see home/common/optional/helper-scripts/yubikey-enroll.sh
#
# Without the resulting ~/.config/Yubico/u2f_keys file, pam_u2f silently falls
# through to password — sudo still works, just without the touch prompt.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.yubikey;

  # Activate every seat0 session. Hardcoding `loginctl activate 1` is unreliable
  # because session IDs aren't deterministic (greetd respawn, suspend cycles,
  # multi-tty login can all shift the user's session away from 1). Iterating
  # over all seat0 sessions activates the foreground one (no-op for it) and
  # silently skips closing/dead sessions.
  activateSeat0Sessions = pkgs.writeShellScript "yubikey-activate-seat0" ''
    set -eu
    ${pkgs.systemd}/bin/loginctl list-sessions --no-legend 2>/dev/null \
      | ${pkgs.gawk}/bin/awk '$4 == "seat0" { print $1 }' \
      | while read -r sid; do
          ${pkgs.systemd}/bin/loginctl activate "$sid" 2>/dev/null || true
        done
  '';

  # Cryptographic unlock-on-insert. Runs pamtester against the dedicated
  # `yubikey-unlock` PAM service (pam_u2f only). pam_u2f issues a fresh
  # challenge to the key, which signs it with a private key bound inside its
  # secure element and requires a capacitive touch. On success the helper
  # emits the logind Unlock signal that hypridle's unlock_cmd handles.
  #
  # Caveats:
  #   - Touch proves user *intent*, not user *identity* — anyone holding the
  #     key can tap it. Defends against spoofed USB devices, not bag theft.
  #   - The `cue` prompt has no TTY to write to (we redirect stdin from
  #     /dev/null and the unit runs detached), so the user sees the
  #     yubikey's LED flashing as the only "please tap" indicator.
  unlockHelper = pkgs.writeShellApplication {
    name = "yubikey-unlock-helper";
    runtimeInputs = with pkgs; [coreutils gawk systemd util-linux pamtester];
    text = ''
      # Brief settle so pcscd/FIDO interfaces are ready before PAM talks to them.
      sleep 0.3

      sess_line=$(loginctl list-sessions --no-legend 2>/dev/null \
        | awk '$4 == "seat0"' | head -1) || true
      if [ -z "''${sess_line:-}" ]; then exit 0; fi
      user=$(echo "$sess_line" | awk '{ print $3 }')
      if [ -z "''${user:-}" ]; then exit 0; fi

      # runuser drops to the target user so pam_u2f resolves their u2f_keys
      # under $HOME. stdin closed because there's no interactive prompt to feed.
      if runuser -u "$user" -- \
           pamtester yubikey-unlock "$user" authenticate \
           </dev/null
      then
        loginctl unlock-sessions
      fi
    '';
  };
in {
  options.yubikey = {
    enable = lib.mkEnableOption "yubikey support: pcscd, udev rules, and FIDO U2F PAM for login and sudo";

    autoScreenActivate = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Activate every seat0 session when a yubikey FIDO device is inserted.
        Does NOT bypass the lock screen — the user still authenticates
        normally. Useful when the screen has blanked from idle.
      '';
    };

    autoScreenUnlock = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Dismiss the lock screen when a yubikey is inserted AND the user
        physically taps it. Cryptographically bound: the udev rule fires a
        helper that runs pamtester against a dedicated `yubikey-unlock` PAM
        service containing only pam_u2f. The yubikey must hold a credential
        enrolled in `~/.config/Yubico/u2f_keys` (via the yubikey-enroll
        script), and the user must touch the key. On success the helper
        calls `loginctl unlock-sessions`, which hypridle's `unlock_cmd`
        turns into a SIGUSR1 to hyprlock.

        UX: insert key -> yubikey LED flashes asking for a tap (no on-screen
        prompt — the udev-launched helper has no TTY for the `cue` text)
        -> tap -> unlock. No password.

        Security model: identical to sudo's tap auth. Defeats spoofed-serial
        USB devices. Does NOT defeat a stolen physical key — anyone holding
        the key can tap it.
      '';
    };

    autoScreenLock = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Lock all sessions when a yubikey FIDO device is removed.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.pcscd.enable = true;

    services.udev.packages = [
      pkgs.yubikey-personalization
      pkgs.libfido2
    ];

    environment.systemPackages = with pkgs; [
      yubikey-manager
      libfido2
      pam_u2f
      pamtester
    ];

    security.pam = {
      u2f = {
        enable = true;
        settings.cue = true;
      };
      services = {
        login.u2fAuth = true;
        sudo.u2fAuth = true;

        # Disable U2F for greetd — initial graphical login is password-only.
        # Reason: pam_gnome_keyring needs PAM_AUTHTOK (the password) to decrypt
        # the login keyring. U2F provides no password, so a tap-only login
        # leaves the keyring locked, breaking 1Password / NetworkManager
        # secrets / etc. With pam_u2f removed from greetd's stack, pam_unix
        # captures the password normally and the keyring unlocks.
        #
        # Sudo, hyprlock, and TTY `login` keep the default `sufficient` so
        # tap-to-auth still works there.
        greetd.u2fAuth = lib.mkIf config.services.greetd.enable false;

        # Dedicated PAM service used by the autoScreenUnlock helper. Contains
        # only pam_u2f so pamtester can perform a tap-only credential check
        # without dragging in the password / keyring stack.
        yubikey-unlock.text = lib.mkIf cfg.autoScreenUnlock ''
          auth required ${pkgs.pam_u2f}/lib/security/pam_u2f.so cue
          account required ${pkgs.linux-pam}/lib/security/pam_permit.so
        '';
      };
    };

    services.udev.extraRules =
      lib.optionalString cfg.autoScreenActivate ''
        SUBSYSTEM=="hid", ACTION=="add", ENV{HID_NAME}=="Yubico Yubi*", RUN+="${activateSeat0Sessions}"
      ''
      + lib.optionalString cfg.autoScreenUnlock ''
        SUBSYSTEM=="hid", ACTION=="add", ENV{HID_NAME}=="Yubico Yubi*", RUN+="${pkgs.systemd}/bin/systemd-run --no-block ${unlockHelper}/bin/yubikey-unlock-helper"
      ''
      + lib.optionalString cfg.autoScreenLock ''
        SUBSYSTEM=="hid", ACTION=="remove", ENV{HID_NAME}=="Yubico Yubi*", RUN+="${pkgs.systemd}/bin/loginctl lock-sessions"
      '';
  };
}
