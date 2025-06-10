# Justfile Recipes

This document describes all available Just recipes in this Nix configuration, organized by functional groups.

## Recipe Groups

### 🔍 Validation
Commands for checking and validating your configuration.

#### `just check`
**Description**: Check flake configuration with pre-validation warnings
**Usage**: `just check`

Validates your Nix flake configuration with pre-checks for platform compatibility. On Darwin systems, shows warnings about Linux-specific configurations that will error out.

**Example**:
```bash
just check
```

#### `just check-trace`
**Description**: Check flake configuration with detailed trace output
**Usage**: `just check-trace`

Similar to `check` but provides detailed trace information for debugging configuration issues.

#### `just check-sops`
**Description**: Validate SOPS configuration
**Usage**: `just check-sops`

Validates your SOPS (Secrets OPerationS) encrypted secrets configuration using the custom validation script.

### 🖥️ System
Core system management commands.

#### `just rebuild [hostname]`
**Description**: Rebuild system configuration for specified hostname
**Usage**: `just rebuild [hostname]`
**Alias**: `r`

Rebuilds your system configuration. If no hostname is provided, uses the current system hostname.

**Examples**:
```bash
just rebuild              # Rebuild current system
just rebuild odin         # Rebuild for host 'odin'
just r workstation       # Using alias
```

#### `just rebuild-full [hostname]`
**Description**: Full system rebuild with validation - requires SOPS and reboot after initial rebuild
**Usage**: `just rebuild-full [hostname]`
**Alias**: `rf`

Performs a complete rebuild including validation. Requires SOPS to be running and you must reboot after the initial rebuild.

#### `just rebuild-trace [hostname]`
**Description**: Rebuild with trace output for debugging
**Usage**: `just rebuild-trace [hostname]`

Rebuilds with detailed trace output for debugging build issues.

#### `just rebuild-update`
**Description**: Update dependencies then rebuild system
**Usage**: `just rebuild-update`

Convenience command that runs `update` followed by `rebuild`.

#### `just tmpfiles-create`
**Description**: Manually create systemd temporary files
**Usage**: `just tmpfiles-create`

Manually triggers systemd temporary file creation. Useful for debugging systemd-tmpfiles configurations.

### 🧹 Maintenance
System cleanup and maintenance commands.

#### `just clean` ⚠️
**Description**: Clean up Nix store and collect garbage
**Usage**: `just clean`
**Confirmation**: Required

Removes all unused Nix store paths and runs garbage collection. **This is destructive and requires confirmation.**

### 🛠️ Development
Development and debugging tools.

#### `just debug [hostname]`
**Description**: Debug host configuration in nix repl
**Usage**: `just debug [hostname]`

Opens a Nix REPL with your host configuration loaded for interactive debugging. Defaults to current hostname if not specified.

**Examples**:
```bash
just debug              # Debug current host
just debug odin         # Debug specific host
```

Once in the REPL, you can explore your configuration:
```nix
# In nix repl
config.services.nginx   # Explore nginx config
config.users.users      # Check user configurations
```

#### `just eval [attr] [hostname]`
**Description**: Evaluate and display configuration attributes
**Usage**: `just eval [attr] [hostname]`

Evaluates specific configuration attributes and displays them as formatted JSON.

**Examples**:
```bash
just eval config.services.nginx odin    # Show nginx config
just eval config.users                  # Show user config for current host
```

#### `just diff`
**Description**: Show git diff excluding flake.lock
**Usage**: `just diff`
**Alias**: `d`

Shows git differences while excluding the `flake.lock` file, which changes frequently and isn't usually relevant for configuration reviews.

### 📦 Dependencies
Package and dependency management.

#### `just update [args...]`
**Description**: Update flake inputs
**Usage**: `just update [args...]`
**Alias**: `u`

Updates Nix flake inputs. You can specify specific inputs to update or update all.

**Examples**:
```bash
just update                    # Update all inputs
just update nixpkgs           # Update only nixpkgs
just update nixpkgs home-manager  # Update specific inputs
```

#### `just update-packages [args...]`
**Description**: Update specific packages using custom script
**Usage**: `just update-packages [args...]`

Uses a custom script to update specific packages. Check `scripts/update-packages.sh` for supported packages.

### 🔐 Secrets
SOPS encrypted secrets management.

#### `just sops`
**Description**: Edit encrypted secrets file using SOPS
**Usage**: `just sops`

Opens the encrypted secrets file in your default editor using SOPS for decryption/encryption.

**Requirements**:
- SOPS must be installed
- Age key must be configured at `~/.config/sops/age/keys.txt`

#### `just age-key`
**Description**: Generate new age encryption key
**Usage**: `just age-key`

Generates a new age encryption key for SOPS. Use this when setting up secrets on a new machine.

#### `just rekey` ⚠️
**Description**: Update all SOPS encryption keys
**Usage**: `just rekey`
**Confirmation**: Required

Updates all SOPS encryption keys. **This affects all encrypted secrets and requires confirmation.**

### 💿 Installation
System installation and deployment commands.

#### `just iso`
**Description**: Build NixOS ISO image
**Usage**: `just iso`

Builds a NixOS ISO installer image. The resulting ISO will be in the `result/iso/` directory.

#### `just iso-install [drive]` ⚠️
**Description**: Install ISO to specified drive
**Usage**: `just iso-install /dev/sdX`
**Confirmation**: Required

**⚠️ DANGEROUS**: Writes the built ISO to the specified drive. **This will overwrite all data on the target drive.**

#### `just disko [drive] [password]` ⚠️
**Description**: Partition and encrypt drive using disko
**Usage**: `just disko /dev/nvme0n1 mypassword`
**Confirmation**: Required

**⚠️ EXTREMELY DANGEROUS**: Partitions and encrypts a drive using disko configuration. **ALL DATA ON THE DRIVE WILL BE PERMANENTLY LOST.**

### 🚀 Deployment
Remote deployment and synchronization.

#### `just sync [host] [user]`
**Description**: Sync configuration to remote host
**Usage**: `just sync hostname [username]`

Syncs your configuration to a remote host via rsync over SSH.

**Examples**:
```bash
just sync odin              # Sync to odin as default user
just sync server root       # Sync to server as root
```

#### `just sync-secrets [host] [user]`
**Description**: Sync secrets to remote host
**Usage**: `just sync-secrets hostname [username]`

Syncs encrypted secrets to a remote host.

#### `just sync-ssh [host] [user]`
**Description**: Sync SSH keys to remote host
**Usage**: `just sync-ssh hostname [username]`

Syncs your SSH keys to a remote host.

#### `just nixos-anywhere [hostname] [ip] [user] [ssh_opts]`
**Description**: Deploy NixOS to remote host using nixos-anywhere
**Usage**: `just nixos-anywhere myhost 192.168.1.100 [root] [ssh_options]`

Deploys NixOS to a remote machine using nixos-anywhere. This is for installing NixOS on a fresh machine remotely.

**Examples**:
```bash
just nixos-anywhere odin 192.168.1.100
just nixos-anywhere server 10.0.0.50 root "-p 2222"
```

## Common Workflows

### Daily Development
```bash
# Check what's changed
just diff

# Validate and rebuild
just check && just rebuild

# Update and rebuild
just update && just rebuild
```

### Setting up a New Machine
```bash
# Generate age key for secrets
just age-key

# Build and install ISO
just iso
just iso-install /dev/sdX

# After installation, deploy configuration
just nixos-anywhere hostname ip.address
```

### Secrets Management
```bash
# Edit secrets
just sops

# Validate secrets are working
just check-sops

# Update encryption keys (when adding new machines)
just rekey
```

### Troubleshooting
```bash
# Detailed validation
just check-trace

# Debug configuration interactively
just debug hostname

# Check specific configuration values
just eval config.services.nginx hostname

# Clean rebuild
just clean && just rebuild
```

## Tips

1. **Use aliases**: Most common commands have short aliases (`r`, `rf`, `u`, `d`)
2. **Tab completion**: Just supports tab completion for recipe names
3. **Help**: Run `just --list` to see all available recipes
4. **Confirmation prompts**: Destructive operations require confirmation for safety
5. **Platform awareness**: Commands automatically adapt to Darwin vs Linux environments