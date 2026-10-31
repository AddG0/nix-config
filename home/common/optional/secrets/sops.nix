{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: {
  sops = {
    # Patched in overlays/common/input-packages: decrypts each sops file once and
    # concurrently, instead of one serial KMS round trip per secret.
    package = pkgs.sops-install-secrets;

    age = {
      keyFile = "${config.home.homeDirectory}/.config/sops-nix/age/keys.txt";
      generateKey = true;
    };

    secrets."github/token".sopsFile = "${inputs.nix-secrets}/global/api-keys/development.yaml";

    # A token in access-tokens shows up in `nix config show`; netrc keeps it to a path.
    templates."nix-netrc".content = ''
      machine api.github.com login x-access-token password ${config.sops.placeholder."github/token"}
    '';
  };

  # Default gui/$UID launchd domain needs a graphical login, so activation over
  # SSH on headless darwin (ghost) fails with "Bootstrap failed: 125"; user/$UID
  # works without a GUI session. Inert on Linux (systemd path, no launchd).
  launchd.agents.sops-nix.domain = "user";

  # sops-nix's own darwin activation (upstream modules/home-manager/sops.nix)
  # hardcodes the gui/$UID domain when reloading the agent, so it hits the same
  # 125 regardless of the option above. Retarget the reload to user/$UID.
  home.activation.sops-nix = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (lib.mkForce (
    lib.hm.dag.entryAfter ["writeBoundary"] ''
      domain="user/$(id -u)"
      run /bin/launchctl bootout "$domain/org.nix-community.home.sops-nix" 2>/dev/null || true
      run /bin/launchctl bootstrap "$domain" "${config.home.homeDirectory}/Library/LaunchAgents/org.nix-community.home.sops-nix.plist"
    ''
  ));

  nix.extraOptions = ''
    netrc-file = ${config.sops.templates."nix-netrc".path}
  '';

  home.packages = with pkgs; [
    sops
    age
  ];

  programs.zsh.initContent = ''
    export GITHUB_TOKEN=$(cat ${config.sops.secrets."github/token".path})
    export SOPS_AGE_KEY_FILE=~/.config/sops-nix/age/keys.txt
  '';

  # This is so I can use sops in the shell anywhere
  home.file.".sops.yaml" = {
    source = ./.sops.yaml;
  };
}
