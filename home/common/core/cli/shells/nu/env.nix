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

      $env.NIX_PATH = [
        $"darwin-config=($env.HOME)/.nixpkgs/darwin-configuration.nix"
        "/nix/var/nix/profiles/per-user/root/channels"
      ]

      $env.NIX_SSL_CERT_FILE = "/nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt"

      $env.TERMINFO_DIRS = [
        $"($env.HOME)/.nix-profile/share/terminfo"
        $"/etc/profiles/per-user/($env.USER)/share/terminfo"
        "/run/current-system/sw/share/terminfo"
        "/nix/var/nix/profiles/default/share/terminfo"
        "/usr/share/terminfo"
      ]
    '';
}
