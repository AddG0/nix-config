{config, ...}: let
  # Both users' files, wallets, browsers and games.
  everyUser = [
    "Desktop"
    "Documents"
    "Downloads"
    "Games"
    "Music"
    "Pictures"
    "Videos"
    {
      directory = ".local/share/keyrings";
      mode = "0700";
    }
    ".local/share/kwalletd"
    ".config/chromium"
    ".config/zen"
    ".mozilla"
    ".local/share/decky"
    ".local/share/PrismLauncher"
    ".config/heroic"
    ".local/share/Steam"
    # Each user's Proton prefixes for the shared library: saves and settings of those games.
    ".local/share/steam-library-compatdata"
    # umu's Steam Runtime for Heroic's Proton games; 175 MB re-downloaded otherwise.
    ".local/share/umu"
    ".local/state/wireplumber"
    ".steam"
  ];
in {
  environment.persistence.${config.hostSpec.persistFolder} = {
    directories = [
      "/etc/NetworkManager/system-connections"
      "/var/cache/fwupd"
      "/var/lib/bluetooth"
      "/var/lib/decky-loader"
      "/var/lib/fwupd"
      "/var/lib/NetworkManager"
      "/var/lib/power-profiles-daemon"
      "/var/lib/sbctl"
      "/var/lib/sddm"
      "/var/lib/steam-library-files"
      "/var/lib/tailscale"
      "/var/lib/upower"
      config.gaming.steam.sharedLibrary
    ];

    users.gamer = {
      directories =
        everyUser
        ++ [
          ".config/discord"
          ".config/spotify"
          ".local/share/wallpapers"
          # Its last-run markers; without them it reruns the panel script, deleting appletsrc, every login.
          ".local/share/plasma-manager"
        ];
      # Symlinks: KConfig saves by renaming over the file, which a bind-mounted file refuses.
      files =
        map (file: {
          inherit file;
          method = "symlink";
        }) [
          ".config/kwinoutputconfig.json"
          ".config/kscreenlockerrc"
          ".config/kwinrc"
          ".config/plasma-org.kde.plasma.desktop-appletsrc"
          ".config/plasmashellrc"
        ];
    };

    users.${config.hostSpec.primaryUsername}.directories =
      everyUser
      ++ [
        "nix-config"

        # Keys, secrets and sign-ins
        {
          directory = ".ssh";
          mode = "0700";
        }
        {
          directory = ".gnupg";
          mode = "0700";
        }
        ".config/1Password"
        ".config/op"
        ".config/sops-nix"
        ".config/Yubico"
        ".pki"

        # Chat and phone
        ".config/discord"
        ".config/Slack"
        ".config/kdeconnect"

        # Media and gaming
        ".config/spotify"
        ".config/r2modman"
        ".config/r2modmanPlus-local"
        ".config/openrazer"
        ".config/wootility"
        ".local/share/RLBot5"
        ".local/share/rlbotgui"
        ".local/state/bakkesmod"
        ".local/state/rlbot"

        # Shell and editor history
        ".local/share/atuin"
        ".local/share/direnv"
        ".local/share/nix"
        ".local/share/nvim"
        ".local/share/tmux"
        ".local/share/zoxide"
        ".local/state/nvim"
        ".local/state/zsh"
      ];
  };
}
