{
  pkgs,
  lib,
  config,
  ...
}: let
  # Convert home.sessionVariables to Nushell env variable assignments
  sessionVarsString = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: value: ''$env.${name} = "${value}"'') config.home.sessionVariables
  );
in {
  programs.nushell.extraEnv =
    ''
      # Set all home.sessionVariables for Nushell
      # (Nushell doesn't automatically pick these up)
      ${sessionVarsString}
    ''
    + lib.optionalString pkgs.stdenv.isDarwin ''
      # Nix environment setup for nushell as login shell on macOS
      # Nushell doesn't automatically source /etc/bashrc where nix-darwin sets up the environment
      # See: https://discourse.nixos.org/t/any-nix-darwin-nushell-users/37778

      $env.__NIX_DARWIN_SET_ENVIRONMENT_DONE = 1

      # Only set PATH if it's not already set by nix shell/develop
      # This preserves the PATH that nix shell sets up with packages
      if "__ETC_PROFILE_NIX_SOURCED" not-in $env {
        $env.PATH = [
          $"($env.HOME)/.nix-profile/bin"
          $"/etc/profiles/per-user/($env.USER)/bin"
          "/run/current-system/sw/bin"
          "/nix/var/nix/profiles/default/bin"
          "/usr/local/bin"
          "/usr/bin"
          "/usr/sbin"
          "/bin"
          "/sbin"
        ]
      }

      $env.NIX_PATH = [
        $"darwin-config=($env.HOME)/.nixpkgs/darwin-configuration.nix"
        "/nix/var/nix/profiles/per-user/root/channels"
      ]

      $env.NIX_SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt"

      $env.TERMINFO_DIRS = [
        $"($env.HOME)/.nix-profile/share/terminfo"
        $"/etc/profiles/per-user/($env.USER)/share/terminfo"
        "/run/current-system/sw/share/terminfo"
        "/nix/var/nix/profiles/default/share/terminfo"
        "/usr/share/terminfo"
      ]

      $env.XDG_CONFIG_DIRS = [
        $"($env.HOME)/.nix-profile/etc/xdg"
        $"/etc/profiles/per-user/($env.USER)/etc/xdg"
        "/run/current-system/sw/etc/xdg"
        "/nix/var/nix/profiles/default/etc/xdg"
      ]

      $env.XDG_DATA_DIRS = [
        $"($env.HOME)/.nix-profile/share"
        $"/etc/profiles/per-user/($env.USER)/share"
        "/run/current-system/sw/share"
        "/nix/var/nix/profiles/default/share"
      ]

      $env.NIX_USER_PROFILE_DIR = $"/nix/var/nix/profiles/per-user/($env.USER)"

      $env.NIX_PROFILES = [
        "/nix/var/nix/profiles/default"
        "/run/current-system/sw"
        $"/etc/profiles/per-user/($env.USER)"
        $"($env.HOME)/.nix-profile"
      ]

      # Append user channels to NIX_PATH if they exist
      if ($"($env.HOME)/.nix-defexpr/channels" | path exists) {
        $env.NIX_PATH = ($env.NIX_PATH | append $"($env.HOME)/.nix-defexpr/channels")
      }

      # Set NIX_REMOTE to daemon if /nix/var/nix/db is not writable
      if (false in (ls -l `/nix/var/nix` | where type == dir | where name == "/nix/var/nix/db" | get mode | str contains "w")) {
        $env.NIX_REMOTE = "daemon"
      }
    '';
}
