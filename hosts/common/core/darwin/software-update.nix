_: {
  system.defaults = {
    CustomSystemPreferences = {
      # check daily, install critical updates, disable macos updates
      "/Library/Preferences/com.apple.SoftwareUpdate" = {
        AutomaticallyInstallAppUpdates = false;
        AutomaticallyInstallMacOSUpdates = false;
        AutomaticCheckEnabled = true;
        AutomaticDownload = false;
        ConfigDataInstall = true;
        CriticalUpdateInstall = true;
        restrict-software-update-require-admin-to-install = true;
        ScheduleFrequency = 1;
      };
    };

    CustomUserPreferences = {
      "com.apple.SoftwareUpdate" = {
        AutomaticCheckEnabled = true;
        # Check for software updates daily, not just once per week
        ScheduleFrequency = 1;
        # Download newly available updates in background
        AutomaticDownload = 1;
        # Install System data files & security updates
        CriticalUpdateInstall = 1;
      };
      "com.apple.TimeMachine".DoNotOfferNewDisksForBackup = true;
      # Turn on app auto-update
      "com.apple.commerce".AutoUpdate = true;
    };
  };
}
