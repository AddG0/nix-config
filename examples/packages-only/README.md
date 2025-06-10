# Using Packages Only

This example demonstrates how to use packages from this nix-config repository without importing all the heavy system configuration dependencies.

## Benefits

### Before (Monolithic Flake)
When someone wanted to use your packages, they had to import:
- nixpkgs
- home-manager  
- nix-darwin
- sops-nix
- hardware
- stylix
- All personal repositories
- And many more...

**Total**: 20+ inputs just to get some packages!

### After (Flake-Parts Separation)
Now they only need:
- nixpkgs
- your-config (which only needs nixpkgs for packages)

**Total**: 2 inputs!

## Usage

```bash
# Use a package directly
nix build github:addg0/nix-config#themes

# Use in another flake
nix flake init -t github:addg0/nix-config#packages-only

# Or add to your flake.nix:
inputs.addg-packages = {
  url = "github:addg0/nix-config";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

## What's Available

The packages output includes everything from `pkgs/common/`:

```bash
# List all available packages
nix flake show github:addg0/nix-config --json | jq '.packages'

# Build a specific package
nix build github:addg0/nix-config#package-name
```

## Structure

```
parts/
├── packages.nix    # 📦 Clean packages (nixpkgs only)
├── overlays.nix    # 🔧 Package overlays  
├── hosts.nix       # 🏠 System configs (all deps)
└── devshell.nix    # 🛠️ Development environment
```

Only `packages.nix` and `overlays.nix` are needed for package consumers! 