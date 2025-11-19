[![Lint Nix](https://github.com/addg0/nix-config/actions/workflows/lint-nix.yml/badge.svg)](https://github.com/addg0/nix-config/actions/workflows/lint-nix.yml)

<div align="center">
  <h1>
    <img width=600" src="assets/icons/nixos.svg" /><br />
    Add's Nix-Config
  </h1>

  <h3><em>Where am I?</em></h3>
  <h4>You're in a rabbit hole.</h4>

  <h3><em>How did I get here?</em></h3>
  <h4>The door opened; you got in.</h4>
</div>

---

## 🚀 Highlights

- **Multi-Platform** support for both NixOS and Darwin (macOS)
- **Flake-based** multi-host, multi-user NixOS and Home-Manager configuration
- **Modular & Composable** configs for both system and user layers
- **Secrets Management** via `sops-nix` and a private `nix-secrets` repo
- **Remote Bootstrapping** and ISO generation with `nixos-anywhere`
- **Automation Recipes** to streamline setup and rebuilds

---

## 📦 Requirements

- NixOS 23.11 or later
- Strong understanding of Nix and NixOS concepts
- Experience with flakes and home-manager
- Familiarity with system administration and Linux
- Patience and persistence
- A good chunk of disk space

This is my personal NixOS configuration that I use to manage my systems. It's not designed to be a drop-in solution - you'll need to understand the code to adapt it for your needs. The configuration assumes you're comfortable with Nix expressions, flakes, and system administration.

> Looking for a well-documented configuration? Check out [EmergentMind's Nix config](https://github.com/EmergentMind/nix-config/tree/dev).

---

## 🗺️ Project Structure

```sh
.
├── flake.nix          # Flake inputs and configuration
├── hosts/
│   ├── common/        # Shared configurations
│   │   ├── core/      # Essential system configs
│   │   │   ├── darwin/    # macOS-specific core
│   │   │   └── nixos/     # NixOS-specific core
│   │   ├── desktops/  # Desktop environment configs
│   │   ├── disks/     # Disk configuration templates
│   │   ├── optional/  # Optional system modules
│   │   └── users/     # User configurations
│   ├── darwin/        # macOS-specific host configs
│   └── nixos/         # NixOS-specific host configs
├── home/              # Home-manager configurations
│   └── primary/       # Primary user config
│       ├── common/    # Shared home configs
│       │   ├── core/  # Essential home setup
│       │   ├── darwin/    # macOS-specific core
│       │   └── nixos/     # NixOS-specific core
│       ├── optional/  # Optional home modules
│       └── desktops/  # Desktop customization
├── modules/           # Custom modules
│   ├── common/        # Shared modules
│   ├── darwin/        # macOS-specific modules
│   ├── home/          # Home-manager modules
│   └── nixos/         # NixOS-specific modules
├── lib/               # Helper functions and utilities
├── pkgs/              # Custom packages
│   ├── common/        # Cross-platform packages
│   ├── darwin/        # macOS-specific packages
│   └── nixos/         # NixOS-specific packages
├── scripts/           # Automation and helper scripts
├── templates/         # Project templates
├── assets/            # Static assets (wallpapers, etc.)
└── docs/              # Documentation and guides
```

---

## 🔐 Secrets Management

Secrets are pulled from a private flake input (`nix-secrets`) and decrypted using [sops-nix](https://github.com/Mic92/sops-nix). For more, read the [Secrets Management Guide](https://unmovedcentre.com/posts/secrets-management/).

---

## 🧭 Roadmap & TODOs

Ongoing improvements are tracked in [docs/TODO.md](docs/TODO.md).

Completed features are noted in their respective stages.

---

## 📚 Resources

- [Nix.dev Docs](https://nix.dev)
  - [Best Practices](https://nix.dev/guides/best-practices)
- [Noogle - Nix API Search](https://noogle.dev/)
- [NixOS Wiki](https://wiki.nixos.org/)
- [NixOS & Flakes Book](https://nixos-and-flakes.thiscute.world/) by Ryan Yin
- [Impermanence](https://github.com/nix-community/impermanence)
- YubiKey:
  - <https://wiki.nixos.org/wiki/Yubikey>
  - [DrDuh Guide](https://github.com/drduh/YubiKey-Guide)

---

## 🙏 Acknowledgements

- [Ryan Yin](https://github.com/ryan4yin/nix-config) — Flake structure and Darwin integration patterns
- [EmergentMind](https://github.com/EmergentMind) — Initial project architecture and modular design
