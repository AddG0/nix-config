# Home-manager configuration discovery and exports
{
  self,
  inputs,
  ...
}: let
  # Use flake.lib (which carries `custom`) and layer home-manager's `hm` on
  # top — home-manager modules expect both. Mirrors hosts/flake-module.nix.
  lib = self.lib.extend (_self: _super: {
    inherit (inputs.home-manager.lib) hm;
  });

  # Scan home/primary/ for host .nix files (each file = one home-manager config)
  hostFiles = builtins.filter (
    name: lib.hasSuffix ".nix" name && name != "default.nix"
  ) (builtins.attrNames (builtins.readDir ./primary));

  mkHostName = file: lib.removeSuffix ".nix" file;

  # pkgs must be chosen before a host's module evaluates, so we read
  # hostSpec.hostPlatform as plain data first: call the module with dummy args
  # (null per its signature, real `lib` since hostSpec literals may reference
  # it). config/pkgs are never forced because the read is lazy.
  systemFor = file: let
    f = import ./primary/${file};
    dummyArgs = builtins.mapAttrs (_: _: null) (builtins.functionArgs f) // {inherit lib;};
  in
    ((f dummyArgs).hostSpec or {}).hostPlatform or "x86_64-linux";

  # Placeholder hostSpec for standalone `home-manager switch`. common/core seeds
  # config.hostSpec from this at mkDefault priority, so a host file can override
  # any field. Integrated hosts get real values from their NixOS/Darwin config.
  mkHostSpec = hostName: system: {
    inherit hostName;
    primaryUsername = "primary";
    handle = "primary";
    isMinimal = false;
    hostType = "desktop";
    isDarwin = lib.hasSuffix "darwin" system;
    disableSops = true;
    hostPlatform = system;
    system.stateVersion = "24.05";
    domain = "example.com";
    email = {
      personal = "user@example.com";
      work = "user@work.example.com";
    };
    userFullName = "Example User";
    githubEmail = "user@example.com";
    networking = {
      prefixLength = 24;
      ports.tcp.ssh = 22;
      ssh.extraConfig = "";
      hostsAddr = {};
    };
  };

  # Standalone, portable nvim built via nixvim's documented `evalNixvim` — the
  # same prefix-less modules the home-manager wrapper imports, with no host /
  # stylix / secret inputs. Self-contained (config baked in, ignores
  # ~/.config/nvim), so `nix run github:AddG0/nix-config#nvim` works anywhere.
  #
  # Stylix isn't present standalone, so feed the nvim modules the `colors` arg
  # parsed from the exact same base16 scheme the hosts theme with
  # (inputs.tt-schemes catppuccin-mocha), so the standalone palette can't drift
  # from Stylix.
  catppuccinMocha = let
    content = builtins.readFile "${inputs.tt-schemes}/base16/catppuccin-mocha.yaml";
    toPair = line: let
      m = builtins.match "  (base0[0-9A-Fa-f]+): \"(#[0-9a-fA-F]+)\".*" line;
    in
      if m == null
      then null
      else lib.nameValuePair (builtins.elemAt m 0) (builtins.elemAt m 1);
  in
    lib.listToAttrs (lib.filter (x: x != null) (map toPair (lib.splitString "\n" content)));
  nvimFor = system:
    (inputs.nixvim.lib.evalNixvim {
      inherit system;
      # `self` → nixd's nixpkgs expr; `osConfig = null` → nix.nix skips host hover.
      extraSpecialArgs = {
        inherit self;
        osConfig = null;
      };
      modules =
        lib.custom.scanPaths ./common/core/nixvim
        ++ [
          {
            # Same overlay/config the hosts use, so custom pkgs (kotlin-lsp, …) resolve.
            nixpkgs.overlays = [self.overlays.default];
            nixpkgs.config.allowUnfree = true;
          }
          {
            _module.args = {
              colors = catppuccinMocha;
              muted = lib.custom.colors.muted catppuccinMocha;
              fonts = {
                monospace.name = "Monaspace Neon NF";
                sansSerif.name = "Inter";
              };
              sshSettings = {};
            };
          }
          {
            # The actual colorscheme comes from stylix's nixvim target on the
            # hosts (mini.base16 + the catppuccin palette). Stylix is absent
            # standalone, so apply the identical colorscheme here.
            plugins.mini.modules.base16.palette = catppuccinMocha;
          }
        ];
    })
    .config
    .build
    .package;

  homeConfigurations = builtins.listToAttrs (map (file: let
      hostName = mkHostName file;
      system = systemFor file;
    in {
      name = hostName;
      value = inputs.home-manager.lib.homeManagerConfiguration {
        pkgs = inputs.nixpkgs.legacyPackages.${system};
        inherit lib;
        extraSpecialArgs = {
          inherit inputs self lib;
          hostSpec = mkHostSpec hostName system;
          desktops = {};
        };
        modules = [
          (lib.custom.relativeToHome "common/core")
          ./primary/${file}
        ];
      };
    })
    hostFiles);
in {
  flake = {
    inherit homeConfigurations;
  };

  # `nix run .#nvim` / `nix run github:AddG0/nix-config#nvim`
  perSystem = {system, ...}: {
    packages.nvim = nvimFor system;
  };
}
