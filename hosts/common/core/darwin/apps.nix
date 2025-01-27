{
  config,
  lib,
  pkgs,
  ...
}:
##########################################################################
#
#  Install all apps and packages here.
#
#  NOTE: Your can find all available options in:
#    https://daiderd.com/nix-darwin/manual/index.html
#
#  NOTE：To remove the uninstalled APPs icon from Launchpad:
#    1. `sudo nix store gc --debug` & `sudo nix-collect-garbage --delete-old`
#    2. click on the uninstalled APP's icon in Launchpad, it will show a question mark
#    3. if the app starts normally:
#        1. right click on the running app's icon in Dock, select "Options" -> "Show in Finder" and delete it
#    4. hold down the Option key, a `x` button will appear on the icon, click it to remove the icon
#
# TODO Fell free to modify this file to fit your needs.
#
##########################################################################
let
  # Homebrew Mirror
  # NOTE: is only useful when you run `brew install` manually! (not via nix-darwin)
  homebrew_mirror_env = {
    HOMEBREW_API_DOMAIN = "https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api";
    HOMEBREW_BOTTLE_DOMAIN = "https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles";
    HOMEBREW_BREW_GIT_REMOTE = "https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git";
    HOMEBREW_CORE_GIT_REMOTE = "https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git";
    HOMEBREW_PIP_INDEX_URL = "https://pypi.tuna.tsinghua.edu.cn/simple";
  };

  local_proxy_env = {
    # HTTP_PROXY = "http://127.0.0.1:7890";
    # HTTPS_PROXY = "http://127.0.0.1:7890";
  };

  homebrew_env_script =
    lib.attrsets.foldlAttrs
    (acc: name: value: acc + "\nexport ${name}=${value}")
    ""
    (homebrew_mirror_env // local_proxy_env);
in {
  environment.variables =
    {
      # Fix https://github.com/LnL7/nix-darwin/wiki/Terminfo-issues
      TERMINFO_DIRS = map (path: path + "/share/terminfo") config.environment.profiles ++ ["/usr/share/terminfo"];

      HOMEBREW_NO_ENV_HINTS = "1";
    }
    # Set variables for you to manually install homebrew packages.
    // homebrew_mirror_env;

  # Set environment variables for nix-darwin before run `brew bundle`.
  system.activationScripts.homebrew.text = lib.mkBefore ''
    echo >&2 '${homebrew_env_script}'
    ${homebrew_env_script}
  '';

  # homebrew need to be installed manually, see https://brew.sh
  # https://github.com/LnL7/nix-darwin/blob/master/modules/homebrew.nix
  homebrew = {
    enable = true; # disable homebrew for fast deploy

    onActivation = {
      autoUpdate = true; # Fetch the newest stable branch of Homebrew's git repo
      upgrade = true; # Upgrade outdated casks, formulae, and App Store apps
      # 'zap': uninstalls all formulae(and related files) not listed in the generated Brewfile
      cleanup = "zap";
    };

    # Applications to install from Mac App Store using mas.
    # You need to install all these Apps manually first so that your apple account have records for them.
    # otherwise Apple Store will refuse to install them.
    # For details, see https://github.com/mas-cli/mas
    masApps = {
      # Xcode = 497799835;
      "Yoink" = 457622435;
    };

    taps = [
      "homebrew/services"

      "hashicorp/tap"
      "nikitabobko/tap" # aerospace - an i3-like tiling window manager for macOS
      "FelixKratz/formulae" # janky borders - highlight active window borders
    ];

    brews = [
      # `brew install`
      # "wget" # download tool
      # "curl" # no not install curl via nixpkgs, it's not working well on macOS!
      # "aria2" # download tool
      # "httpie" # http client
      # "wireguard-tools" # wireguard

      # Usage:
      #  https://github.com/tailscale/tailscale/wiki/Tailscaled-on-macOS#run-the-tailscaled-daemon
      # 1. `sudo tailscaled install-system-daemon`
      # 2. `tailscale up --accept-routes`
      # "tailscale" # tailscale

      # https://github.com/rgcr/m-cli
      "m-cli" #  Swiss Army Knife for macOS
      # "proxychains-ng"
      # "bettercap"

      # commands like `gsed` `gtar` are required by some tools
      # "gnu-sed"
      # "gnu-tar"

      # misc that nix do not have cache for.
      "git-trim"
      "terraform"
      # "terraformer"

      "tomcat@8" # TODO: Delete this after java 8 is no longer needed

      "kubelogin"
      "awscli"
    ];

    # `brew install --cask`
    casks = [
      "arc"
      "firefox@developer-edition"
      "synology-drive"
      "openvpn-connect"
      "1password"
      "orbstack"
      "docker" # Docker Desktop needed for vscode devcontainers
      "sharemouse"
      "caffeine"
      "notchnook" # Dynamic island for macos
      "lens" # preview kubernetes resources

      "balenaetcher"

      "bartender" # tool to manage the menu bar
      "cleanshot" # screenshot tool
      # "menubarx" # browser in the menu bar
      "hovrly" # show different time zones in menu bar
      "imageoptim" # strip metadata from images

      "parallels"

      "amazon-q"
      "aws-vpn-client"

      "notion-calendar"
      "motion"
      # "lens"
      "cursor"

      "autodesk-fusion"

      "langgraph-studio"
      "chatgpt"

      # Misc
      # "shadowsocksx-ng" # proxy tool
      "iina" # video player
      # "raycast" # (HotKey: alt/option + space)search, calculate and run scripts(with many plugins)
      "stats" # beautiful system status monitor in menu bar
      "aerospace" # an i3-like tiling window manager for macOS
      # "reaper"  # audio editor
      # "sonic-pi" # music programming
      "tencent-lemon" # macOS cleaner
      "spotify" # music
      # "blender@lts" # 3D creation suite

      # Development
      "mitmproxy" # HTTP/HTTPS traffic inspector
      "insomnia" # REST client
      "postman"

      # "jdk-mission-control" # Java Mission Control
      # "google-cloud-sdk" # Google Cloud SDK
      "miniforge" # Miniconda's community-driven distribution
    ];
  };
}
