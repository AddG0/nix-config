# Getting Started

## Quick Setup

1. **Clone the configuration**:
   ```bash
   git clone <your-repo> ~/nix-config
   cd ~/nix-config
   ```

2. **First build**:
   ```bash
   just check    # Validate configuration
   just rebuild  # Build system
   ```

3. **Common workflows**:
   ```bash
   just --list              # See all available commands
   just rebuild hostname    # Rebuild specific host
   just update && rebuild   # Update and rebuild
   ```

## Next Steps

- Check out the [Justfile Documentation](../automation/justfile.md) for all available commands
- Review [System Configuration](../system/README.md) for host-specific settings
- See [Modules Documentation](../modules/README.md) for available features

## Troubleshooting

### SOPS Issues
```bash
just check-sops  # Validate secrets
just rekey       # Update encryption keys
```

### Build Failures
```bash
just check-trace     # Detailed error output
just clean && rebuild # Clean rebuild
``` 