---
name: dev-flake
description: Scaffold or update Nix flake dev environments. Use when creating, modernizing, or adding services to a project's flake.nix.
argument-hint: "[language] [services...] — e.g. python-uv postgres, java redis kafka"
context: fork
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

## When to Use

- Setting up a new project's dev environment
- Adding local services (PostgreSQL, Redis, Kafka) to an existing flake
- Fixing or modernizing a project's Nix dev shell

## Required Files

```
project/
├── flake.nix
├── flake.lock   # auto-generated
└── .envrc       # always just: use flake
```

## flake.nix Template

```nix
{
  description = "Project Name";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    git-hooks-nix = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    process-compose-flake.url = "github:Platonic-Systems/process-compose-flake";
    services-flake.url = "github:juspay/services-flake";
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin"];

      imports = [
        inputs.git-hooks-nix.flakeModule
        inputs.process-compose-flake.flakeModule
      ];

      perSystem = {pkgs, config, ...}: let
        # Override language toolchains here
        java = pkgs.jdk21;
        gradle = pkgs.gradle.override {inherit java;};
      in {
        # Local services: `nix run .#services`
        process-compose."services" = {
          imports = [inputs.services-flake.processComposeModules.default];
          settings.processes = {
            pg.shutdown.timeout_seconds = 5;
            redis.shutdown.timeout_seconds = 5;
          };
          services = {
            postgres."pg" = {
              enable = true;
              port = 5432;
              listen_addresses = "127.0.0.1";
              initialDatabases = [{name = "mydb";}];
            };
            redis."redis" = {
              enable = true;
              port = 6379;
              bind = "127.0.0.1";
            };
          };
        };

        pre-commit.settings.hooks = {
          alejandra.enable = true;  # always
          # google-java-format.enable = true;  # Java projects
          # prettier.enable = true;             # JS/TS projects
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            # Add project-specific tools here
          ];
          env = {
            # Static environment variables go here
            # JAVA_HOME = "${java}";
          };
          shellHook = ''
            ${config.pre-commit.installationScript}
          '';
        };
      };
    };
}
```

## Conventions

- **Pin nixpkgs** to a release branch (e.g., `nixos-25.11`)
- **`follows` nixpkgs** on inputs that support it to reduce closure size
- **Shutdown timeouts** on all process-compose services to prevent hangs
- **All tools via Nix** — no global installs, no wrapper scripts (e.g., use `gradle` not `./gradlew`)
- **Prefer `env = { }` over `shellHook` exports** — use `mkShell`'s `env` attr for static environment variables (e.g., `JAVA_HOME`, `UV_NO_SYNC`). Reserve `shellHook` for commands that must run at shell entry (e.g., `pre-commit.installationScript`, `unset`, dynamic values like `$(git rev-parse ...)`)
- Omit `process-compose-flake` and `services-flake` inputs if no local services needed

## Commands

| Command                                | Purpose                       |
| -------------------------------------- | ----------------------------- |
| `direnv allow`                         | Enable environment (one-time) |
| `nix develop`                          | Enter dev shell manually      |
| `nix run .#services`                   | Start local services          |
| `nix flake update`                     | Update all inputs             |
| `nix flake lock --update-input <name>` | Update single input           |

## Language References

When the project uses a specific language ecosystem, load the corresponding reference for inputs, patterns, and conventions:

- For Python projects using `uv` (`pyproject.toml` + `uv.lock`), see [references/uv2nix.md](references/uv2nix.md)

## Steps

1. Ask what language/framework and what local services are needed
2. Scaffold `flake.nix` from the base template, trimming unused sections
3. If a language reference exists, load it and merge those inputs/patterns into the flake
4. Add language-specific packages to `devShells.default.packages`
5. Add appropriate pre-commit hooks for the language
6. Configure services if needed, otherwise remove process-compose inputs
7. Create `.envrc` with `use flake`
8. Run `nix flake lock` to generate the lock file
