{
  config,
  lib,
  pkgs,
  self,
  inputs,
  nix-secrets,
  hostSpec,
  ...
}: let
  platform =
    if hostSpec.isDarwin
    then "darwin"
    else "nixos";
in {
  imports = lib.flatten [
    (lib.custom.scanPaths ./.)
    self.homeModules.default
    ./${platform}
  ];

  inherit hostSpec;

  home = {
    username = lib.mkDefault hostSpec.username;
    homeDirectory = lib.mkDefault hostSpec.home;
    stateVersion = lib.mkDefault hostSpec.system.stateVersion;
    sessionPath = [
      "$HOME/.local/bin"
      "$HOME/scripts/talon_scripts"
    ];
    sessionVariables = {
      FLAKE = "$HOME/nix-config";
      SHELL = "zsh";
      TERM = "xterm-256color";
      TERMINAL = "xterm-256color";
      VISUAL = "nvim";
      EDITOR = "nvim";
      MANPAGER = "bat --paging=always --plain"; # see ./cli/bat.nix
    };
    preferXdgDirectories = true; # whether to make programs use XDG directories whenever supported
  };

  home.packages = with pkgs; [
    # stable.llm
    claude-code # chat with claude
    # Packages that don't have custom configs go here
    coreutils # basic gnu utils
    fd # tree style ls
    findutils # find
    jq # JSON pretty printer and manipulator
    neofetch # fancier system info than pfetch
    #  ncdu # TUI disk usage

    pciutils
    pfetch # system info
    pre-commit # git hooks
    p7zip # compression & encryption
    ripgrep # better grep
    # steam-run # for running non-NixOS-packaged binaries on Nix

    # usbutils
    # stable.bettercap
    # libpcap
    # libusb1

    tree # cli dir tree viewer
    unzip # zip extraction
    unrar # rar extraction
    xdg-utils # provide cli tools such as `xdg-mime` and `xdg-open`
    xdg-user-dirs
    # wev # show wayland events. also handy for detecting keypress codes

    wget # downloader
    zip # zip compression
    sops
    age
    # Misc

    tldr
    gnupg
    gnumake
    ngrok
    mailsy # create and send emails from the terminal
    # llm # chat with llm's from the terminal
    cpulimit # limit the cpu usage of a process

    # Modern cli tools, replacement of grep/sed/...

    fzf # Interactively filter its input using fuzzy searching, not limit to filenames.
    # fd and ripgrep are already included above

    lnav # log file viewer

    sad # CLI search and replace, just like sed, but with diff preview.
    yq-go # yaml processor https://github.com/mikefarah/yq
    just # a command runner like make, but simpler
    delta # A viewer for git and diff output
    hyperfine # command-line benchmarking tool
    gping # ping, but with a graph(TUI)
    doggo # DNS client for humans
    duf # Disk Usage/Free Utility - a better 'df' alternative
    du-dust # A more intuitive version of `du` in rust
    gdu # disk usage analyzer(replacement of `du`)

    # productivity

    caddy # A webserver with automatic HTTPS via Let's Encrypt(replacement of nginx)
    croc # File transfer between computers securely and easily
    # ncdu is already included above
  ];

  nixpkgs = {
    overlays = builtins.attrValues self.overlays;
    config = {
      allowUnfree = true;
      # Workaround for https://github.com/nix-community/home-manager/issues/2942
      allowUnfreePredicate = _: true;
    };
  };

  nix = {
    package = lib.mkDefault pkgs.nix;
    nixPath = [
      "nixpkgs=${inputs.nixpkgs}"
    ];
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      warn-dirty = false;
    };
  };

  programs = {
    home-manager.enable = true; # Let home-manager manage itself
  };

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";
}
