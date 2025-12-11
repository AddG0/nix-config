{
  description = "Add's nix configuration for both NixOS & macOS";

  # the nixConfig here only affects the flake itself, not the system configuration!
  # for more information, see:
  #     https://nixos-and-flakes.thiscute.world/nix-store/add-binary-cache-servers
  nixConfig = {
    # substituers will be appended to the default substituters when fetching packages
    extra-substituters = [
      "https://cache.nixos.org"
      "https://anyrun.cachix.org"
      "https://nix-gaming.cachix.org"
      "https://nixpkgs-wayland.cachix.org"
      "https://nixpkgs-python.cachix.org"
    ];
    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "anyrun.cachix.org-1:pqBobmOjI7nKlsUMV25u9QHa9btJK65/C8vnO3p346s="
      "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
      "nixpkgs-wayland.cachix.org-1:3lwxaILxMRkVhehr5StQprHdEo4IrE8sRho9R9HOLYA="
      "nixpkgs-python.cachix.org-1:hxjI7pFxTyuTHn2NkvWCrAUcNZLNS3ZAvfYNuYifcEU="
    ];
  };

  inputs = {
    #################### Official NixOS and HM Package Sources ####################

    flake-parts.url = "github:hercules-ci/flake-parts";

    # Option 1: Main = unstable (current)
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.follows = "nixpkgs";

    # Option 2: Main = stable (swap comments to switch)
    # nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    # nixpkgs-stable.follows = "nixpkgs";
    # nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-darwin = {
      url = "github:lnl7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hardware.url = "github:nixos/nixos-hardware";
    home-manager = {
      # url = "github:nix-community/home-manager/release-25.05";
      #inputs.nixpkgs.follows = "nixpkgs-stable";
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-homebrew = {
      url = "github:zhaofengli-wip/nix-homebrew";
    };

    #################### Utilities ####################

    # Declarative partitioning and formatting
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Secrets management. See ./docs/secretsmgmt.md
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvirt = {
      url = "https://flakehub.com/f/AshleyYakeley/NixVirt/*.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    vscode-server = {
      url = "github:nix-community/nixos-vscode-server";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ghostty = {
      url = "github:ghostty-org/ghostty";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.rust-overlay.follows = "rust-overlay";
    };

    # vim4LMFQR!
    nixvim = {
      #url = "github:nix-community/nixvim/nixos-24.05";
      #inputs.nixpkgs.follows = "nixpkgs";
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pre-commit-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    claude-desktop = {
      url = "github:k3d3/claude-desktop-linux-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nur-ryan4yin = {
      url = "github:ryan4yin/nur-packages";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nur-ataraxiasjel = {
      url = "github:AtaraxiaSjel/nur";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixpkgs-update = {
      url = "github:nix-community/nixpkgs-update";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    #################### Theming ####################

    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Add base16.nix, base16 schemes and
    # zathura and vim templates to the flake inputs.
    base16.url = "github:SenchoPens/base16.nix";

    tt-schemes = {
      url = "github:tinted-theming/schemes";
      flake = false;
    };

    base16-zathura = {
      url = "github:haozeke/base16-zathura";
      flake = false;
    };

    base16-vim = {
      url = "github:tinted-theming/base16-vim";
      flake = false;
    };

    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    #################### Personal Repositories ####################

    # Private secrets repo.  See ./docs/secretsmgmt.md
    nix-secrets = {
      url = "git+ssh://git@github.com/addg0/nix-secrets.git?ref=main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pterodactyl-addons = {
      url = "git+ssh://git@github.com/addg0/pterodactyl-addons.git?ref=main";
      flake = false;
    };

    lumenboard-player = {
      url = "git+ssh://git@github.com/addg0/lumenboard-player.git?ref=tmp";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ai-toolkit = {
      url = "git+ssh://git@github.com/addg0/ai-toolkit.git?ref=main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    asus-numberpad-driver = {
      url = "github:asus-linux-drivers/asus-numberpad-driver";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux" "x86_64-darwin" "aarch64-darwin"];

      imports = [
        inputs.home-manager.flakeModules.home-manager
        ./lib/flake-module.nix
        ./overlays/flake-module.nix
        ./pkgs/flake-module.nix
        ./modules/flake-module.nix
        ./home/flake-module.nix
        ./hosts/flake-module.nix
        ./deployment/flake-module.nix
        ./checks/flake-module.nix
      ];

      perSystem = {
        pkgs,
        config,
        ...
      }: {
        # Development shell
        devShells = import ./shell.nix {
          inherit pkgs;
          checks = config.checks;
        };
      };
    };
}
