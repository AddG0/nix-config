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
}
