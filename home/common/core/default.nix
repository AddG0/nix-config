{
  lib,
  pkgs,
  self,
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
      SHELL = "nu";
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
    # Packages that don't have custom configs go here
    coreutils # basic gnu utils
    gawk
    gnused
    fd # tree style ls
    findutils # find
    jq # JSON pretty printer and manipulator
    neofetch # fancier system info than pfetch
    #  ncdu # TUI disk usage

    pciutils
    pfetch # system info
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
    # Misc

    tldr
    gnupg
    gnumake
    # llm # chat with llm's from the terminal

    # Modern cli tools, replacement of grep/sed/...

    yq-go # yaml processor https://github.com/mikefarah/yq
    just # a command runner like make, but simpler
    # delta # A viewer for git and diff output
    # hyperfine # command-line benchmarking tool
    # gping # ping, but with a graph(TUI)
    # doggo # DNS client for humans
    duf # Disk Usage/Free Utility - a better 'df' alternative
    dust # A more intuitive version of `du` in rust
    gdu # disk usage analyzer(replacement of `du`)

    # productivity

    croc # File transfer between computers securely and easily
    # ncdu is already included above
  ];

  programs = {
    home-manager.enable = true; # Let home-manager manage itself
  };

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";
}
