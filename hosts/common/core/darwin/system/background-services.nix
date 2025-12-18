{
  config,
  lib,
  pkgs,
  ...
}:
###################################################################################
#
#  Disable/reduce Apple background services
#
#  Note: Many Apple daemons are protected by SIP and cannot be fully disabled.
#  These settings reduce their activity by disabling the features that trigger them.
#
#  All settings below have been verified to exist on macOS.
#
###################################################################################
{
  system = {
    activationScripts = {
      # Disable Spotlight indexing on all volumes
      disableSpotlight = {
        enable = true;
        text = ''
          echo "Disabling Spotlight indexing..."
          sudo mdutil -a -i off 2>/dev/null || true
        '';
      };
    };

    defaults = {
      CustomUserPreferences = {
        # Disable Siri (verified keys)
        "com.apple.assistant.support" = {
          "Assistant Enabled" = false;
        };
        "com.apple.Siri" = {
          StatusMenuVisible = false;
          UserHasDeclinedEnable = true;
          VoiceTriggerUserEnabled = false;
        };

        # Disable Siri suggestions - reduces duetexpertd activity (verified keys)
        "com.apple.suggestions" = {
          SuggestionsAllowGeocode = false;
          SuggestionsAllowEntityExtraction = false;
          SuggestionsAllowMailExtraction = false;
        };

        # Disable Spotlight suggestions / web lookups (verified key)
        "com.apple.lookup.shared" = {
          LookupSuggestionsDisabled = true;
        };

        # Reduce Photos analysis - reduces mediaanalysisd activity (verified key)
        "com.apple.photoanalysisd" = {
          ShouldAnalyze = false;
        };

        # Disable personalized ads (verified keys)
        "com.apple.AdLib" = {
          allowApplePersonalizedAdvertising = false;
          allowIdentifierForAdvertising = false;
        };

        # Disable analytics/diagnostics (verified keys)
        "com.apple.SubmitDiagInfo" = {
          AutoSubmit = false;
        };
        "com.apple.CrashReporter" = {
          DialogType = "none";
        };
      };
    };
  };

  # Launchd daemon to ensure Spotlight stays disabled after reboots
  launchd.daemons.disable-spotlight = {
    script = ''
      /usr/bin/mdutil -a -i off
    '';
    serviceConfig = {
      Label = "org.nixos.disable-spotlight";
      RunAtLoad = true;
      StandardErrorPath = "/var/log/disable-spotlight.log";
      StandardOutPath = "/var/log/disable-spotlight.log";
    };
  };
}
