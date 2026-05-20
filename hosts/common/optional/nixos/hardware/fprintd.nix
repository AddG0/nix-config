# Fingerprint reader (Realtek 2541:fa03)
#
# Enroll:  sudo fprintd-enroll addg
# Verify:  sudo fprintd-verify addg
# List:    fprintd-list addg
# Delete:  sudo fprintd-delete addg
_: {
  services.fprintd.enable = true;

  # Unlock login, lockscreen, and sudo with fingerprint
  security.pam.services.login.fprintAuth = true;
  security.pam.services.swaylock.fprintAuth = true;
  security.pam.services.sudo.fprintAuth = true;
  security.pam.services.greetd.fprintAuth = true;
  # hyprlock doesn't ship a PAM file (unlike swaylock), so NixOS won't
  # generate one unless this attrset exists. Without it hyprlock falls back
  # to /etc/pam.d/su — no fprintd, and password failures log as
  # `pam_unix(su:auth)` instead of `pam_unix(hyprlock:auth)`.
  #   https://github.com/hyprwm/hyprlock/issues/4
  #   https://github.com/hyprwm/hyprlock/issues/545
  security.pam.services.hyprlock.fprintAuth = true;
}
