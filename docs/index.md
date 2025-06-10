# Nix Configuration Documentation

Welcome to the documentation for this Nix configuration repository! This documentation covers the tools, recipes, and workflows used to manage NixOS and Darwin systems.

## 🚀 Quick Start

```bash
# List all available recipes
just --list

# Build and serve this documentation
nix run .#docs
```

## 📚 Documentation Sections

### 🏁 [Getting Started](guides/getting-started.md)
Complete setup guide for new users including:
- Initial configuration steps
- First system build
- Common troubleshooting
- Next steps and workflows

### 🤖 [Automation](automation/justfile.md)
Comprehensive guide to project automation with detailed recipe documentation:
- **🔍 Validation** - Configuration checking and validation
- **🖥️ System** - Core system rebuilding and management
- **🧹 Maintenance** - Cleanup and maintenance tasks
- **🔧 Development** - Development and debugging tools
- **📦 Dependencies** - Package and dependency management
- **🔐 Secrets** - SOPS secrets management
- **💽 Installation** - ISO building and system installation
- **🚀 Deployment** - Remote deployment and sync operations

### 🖥️ [System Configuration](system/README.md)
System-level configuration documentation:
- Host-specific configurations
- Darwin vs NixOS differences
- Hardware configurations
- Adding new hosts

### 🧩 [Modules](modules/README.md)
Custom module documentation and guides:
- Available modules by category
- Module development guidelines
- Configuration examples
- Integration patterns

### 🚀 [Deployment](deployment/README.md)
Remote deployment and multi-host management:
- nixos-anywhere workflows
- Manual deployment strategies
- Multi-host management
- Security considerations

### 📖 [Just Features](justfile-features.md)
Deep dive into Just command runner capabilities:
- Recipe syntax and variables
- Built-in functions and attributes
- Platform-specific recipes
- Error handling and debugging
- Best practices

## 🛠️ Tools and Technologies

This configuration uses several key technologies:

- **[Nix](https://nixos.org/)** - Functional package manager and build system
- **[Just](https://github.com/casey/just)** - Command runner for automation
- **[SOPS](https://github.com/mozilla/sops)** - Secrets management
- **[Home Manager](https://github.com/nix-community/home-manager)** - User environment management
- **[nix-darwin](https://github.com/LnL7/nix-darwin)** - macOS system management

## 📖 Common Workflows

### System Management
```bash
# Update and rebuild system
just rebuild-update

# Check configuration validity
just check

# Clean up old packages
just clean
```

### Development
```bash
# Show configuration changes
just diff

# Debug configuration issues
just debug
just check-trace
```

### Secrets Management
```bash
# Edit encrypted secrets
just sops

# Update encryption keys
just rekey
```

### Remote Deployment
```bash
# Sync configuration to remote host
just sync hostname.example.com

# Deploy to new machine
just nixos-anywhere new-host 192.168.1.100
```

## 🔧 Configuration Structure

```
.
├── docs/               # Documentation files
│   ├── guides/         # Getting started and tutorials
│   ├── automation/     # Justfile and automation guides
│   ├── system/         # System configuration docs
│   ├── modules/        # Module documentation
│   └── deployment/     # Deployment guides
├── flake.nix          # Main flake configuration
├── justfile           # Automation recipes
├── hosts/             # Host-specific configurations
│   ├── nixos/         # NixOS hosts
│   └── darwin/        # macOS hosts
├── modules/           # Reusable configuration modules
├── home/              # Home Manager configurations
├── pkgs/              # Custom packages
└── scripts/           # Helper scripts
```

## 🎯 Getting Help

- **New to this config?** Start with [Getting Started](guides/getting-started.md)
- **Recipe help**: `just --show <recipe-name>`
- **List recipes**: `just --list`
- **Nix help**: `nix --help`
- **Build issues**: `just check-trace`

## 🤝 Contributing

When adding new features:

1. Add appropriate justfile recipes with documentation
2. Use confirmation prompts for destructive operations
3. Organize recipes into logical groups
4. Update documentation in the appropriate folder

---

*This documentation is built with [MkDocs Material](https://squidfunk.github.io/mkdocs-material/) and served via `nix run .#docs`*