{
  config,
  lib,
  inputs,
  self,
  pkgs,
  ...
}: let
  inherit (inputs) nix-homebrew;
in {
  imports = lib.flatten [
    (lib.custom.scanPaths ./.)
    self.darwinModules.default
    nix-homebrew.darwinModules.nix-homebrew
    {
      nix-homebrew = {
        enable = true;
        enableRosetta = config.hostSpec.darwin.isAarch64;
        user = "${config.hostSpec.username}";
        autoMigrate = true;
      };
    }
  ];

  hostSpec = {
    isDarwin = true;
    darwin = {
      isAarch64 = lib.strings.hasInfix "aarch64" config.hostSpec.hostPlatform;
      hasPaidApps = lib.mkDefault (config.hostSpec.username == "addg");
    };
  };

  networking.computerName = config.hostSpec.hostName;
  system.defaults.smb.NetBIOSName = config.hostSpec.hostName;

  system.primaryUser = config.hostSpec.username;

  # Add nushell to available shells
  environment.shells = [pkgs.nushell];

  # Activation script to change shell for existing users
  # Using dscl (consistent with nix-darwin's user module implementation)
  system.activationScripts.users.text = lib.mkAfter ''
    echo "Setting shell to nushell for ${config.hostSpec.username}..."
    dscl . -create /Users/${config.hostSpec.username} UserShell ${pkgs.nushell}/bin/nu
  '';

  users.users.${config.hostSpec.username} = {
    description = config.hostSpec.userFullName;
    # Public Keys that can be used to login to all my PCs, Macbooks, and servers.
    #
    # Since its authority is so large, we must strengthen its security:
    # 1. The corresponding private key must be:
    #    1. Generated locally on every trusted client via:
    #      ```bash
    #      # KDF: bcrypt with 256 rounds, takes 2s on Apple M2):
    #      # Passphrase: digits + letters + symbols, 12+ chars
    #      ssh-keygen -t ed25519 -a 256 -C "ryan@xxx" -f ~/.ssh/xxx`
    #      ```
    #    2. Never leave the device and never sent over the network.
    # 2. Or just use hardware security keys like Yubikey/CanoKey.
    # openssh.authorizedKeys.keys = config.hostSpec.sshAuthorizedKeys;
  };
}
