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

  hostSpec.darwin = {
    isAarch64 = lib.strings.hasInfix "aarch64" config.hostSpec.hostPlatform;
    hasPaidApps = lib.mkDefault (config.hostSpec.username == "addg");
  };

  networking.computerName = config.hostSpec.hostName;
  system.defaults.smb.NetBIOSName = config.hostSpec.hostName;

  environment.systemPackages = with pkgs; [
    git # used by nix flakes
    git-lfs # used by huggingface models

    # archives
    zip
    xz
    zstd
    unzipNLS
    p7zip

    # Text Processing
    # Docs: https://github.com/learnbyexample/Command-line-text-processing
    gnugrep # GNU grep, provides `grep`/`egrep`/`fgrep`
    gnused # GNU sed, very powerful(mainly for replacing text in files)
    gawk # GNU awk, a pattern scanning and processing language
    jq # A lightweight and flexible command-line JSON processor

    # networking tools
    mtr # A network diagnostic tool
    iperf3
    dnsutils # `dig` + `nslookup`
    ldns # replacement of `dig`, it provide the command `drill`
    wget
    curl
    aria2 # A lightweight multi-protocol & multi-source command-line download utility
    socat # replacement of openbsd-netcat
    nmap # A utility for network discovery and security auditing
    ipcalc # it is a calculator for the IPv4/v6 addresses

    # misc
    file
    findutils
    which
    tree
    gnutar
    rsync
  ];

  system.primaryUser = config.hostSpec.username;

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
