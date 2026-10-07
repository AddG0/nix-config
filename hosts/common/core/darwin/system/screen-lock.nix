# Lock on display sleep; since Ventura macOS honours these keys only from a profile, not `defaults`.
{lib, ...}: let
  identifier = "com.addg.screen-lock";
  profile = "/etc/screen-lock.mobileconfig";
  settings = {
    askForPassword = true;
    askForPasswordDelay = 0;
  };

  # Content-derived, so editing `settings` makes the installed profile read as stale.
  uuidFor = salt: let
    h = lib.toUpper (builtins.hashString "sha256" (salt + builtins.toJSON settings));
    s = lib.substring;
  in "${s 0 8 h}-${s 8 4 h}-${s 12 4 h}-${s 16 4 h}-${s 20 12 h}";
  uuid = uuidFor "profile";
in {
  environment.etc."screen-lock.mobileconfig".text = lib.generators.toPlist {escape = true;} {
    PayloadDisplayName = "Screen Lock";
    PayloadIdentifier = identifier;
    PayloadScope = "System";
    PayloadType = "Configuration";
    PayloadUUID = uuid;
    PayloadVersion = 1;
    PayloadContent = [
      (settings
        // {
          PayloadIdentifier = "${identifier}.screensaver";
          PayloadType = "com.apple.screensaver";
          PayloadUUID = uuidFor "screensaver";
          PayloadVersion = 1;
        })
    ];
  };

  # Profiles can't be installed silently without MDM, so activation can only nag.
  system.activationScripts.postActivation.text = ''
    if ! /usr/sbin/system_profiler SPConfigurationProfileDataType 2>/dev/null | grep -qi '${uuid}'; then
      echo "warning: screen lock profile missing or stale; run: open ${profile}, then approve it in System Settings > Privacy & Security > Profiles" >&2
    fi
  '';
}
