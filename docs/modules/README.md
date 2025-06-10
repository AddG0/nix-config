# Modules Documentation

This directory contains documentation for all custom NixOS/Darwin modules in this configuration.

## Module Categories

### Core System Modules
Base system functionality and common configurations.

### Desktop Environment Modules
Window managers, desktop environments, and GUI applications.

### Development Modules
Development tools, editors, and programming language support.

### Services Modules
System services, daemons, and server configurations.

### Security Modules
SOPS secrets management, firewall, and security tooling.

### Apps Modules
Flake apps and utilities for development workflows.

## Available Modules

### [Pterodactyl](PTERODACTYl.md)
Game server management panel with Docker support.

### [Documentation Apps](../project/documentation-apps.md)
Configurable MkDocs Material and Docusaurus documentation servers.

## Module Structure

Each module typically follows this pattern:

```nix
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.mymodule;
in {
  options.services.mymodule = {
    enable = mkEnableOption "My custom module";
    
    setting = mkOption {
      type = types.str;
      default = "default-value";
      description = "Description of the setting";
    };
  };

  config = mkIf cfg.enable {
    # Module implementation
  };
}
```

## Adding New Modules

1. **Create the module file** in appropriate category directory
2. **Add to module imports** in the relevant configuration
3. **Document the module** in this directory
4. **Test the module** with your configuration

## Module Guidelines

- Use proper option types and descriptions
- Provide sensible defaults
- Include example configurations
- Document any special requirements
- Test on both Darwin and NixOS where applicable

## See Also

- [System Configuration](../system/README.md)
- [Getting Started](../guides/getting-started.md)
- [Justfile Automation](../automation/justfile.md) 