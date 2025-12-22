{pkgs, ...}: {
  extensions = [
    pkgs.vscode-marketplace.mkhl.direnv
  ];
  userSettings = {
    # Auto-restart terminal when direnv environment changes
    "direnv.restart.automatic" = true;

    # Hide direnv/devenv cache directories from explorer
    "files.exclude" = {
      "**/.direnv" = true;
      "**/.devenv" = true;
    };

    # Exclude from search
    "search.exclude" = {
      "**/.direnv" = true;
      "**/.devenv" = true;
    };
  };
  # Direnv stdlib snippets for .envrc files
  languageSnippets.shellscript = {
    "use flake" = {
      prefix = "use_flake";
      body = "use flake $0";
      description = "Load a Nix flake devShell";
    };
    "use nix" = {
      prefix = "use_nix";
      body = "use nix $0";
      description = "Load environment from shell.nix or default.nix";
    };
    "watch_file" = {
      prefix = "watch_file";
      body = "watch_file $1";
      description = "Watch a file for changes and reload";
    };
    "watch_dir" = {
      prefix = "watch_dir";
      body = "watch_dir $1";
      description = "Watch a directory for changes";
    };
    "source_env" = {
      prefix = "source_env";
      body = "source_env $1";
      description = "Source another .envrc file";
    };
    "source_env_if_exists" = {
      prefix = "source_env_if_exists";
      body = "source_env_if_exists $1";
      description = "Source another .envrc if it exists";
    };
    "dotenv" = {
      prefix = "dotenv";
      body = "dotenv $0";
      description = "Load a .env file";
    };
    "dotenv_if_exists" = {
      prefix = "dotenv_if_exists";
      body = "dotenv_if_exists $1";
      description = "Load a .env file if it exists";
    };
    "layout" = {
      prefix = "layout";
      body = "layout $1";
      description = "Set up a language-specific layout (python, node, go, etc.)";
    };
    "PATH_add" = {
      prefix = "PATH_add";
      body = "PATH_add $1";
      description = "Add a path to PATH";
    };
    "path_add" = {
      prefix = "path_add";
      body = "path_add $1";
      description = "Add a path to PATH";
    };
    "export" = {
      prefix = "export_env";
      body = "export $1=$2";
      description = "Export an environment variable";
    };
    "strict_env" = {
      prefix = "strict_env";
      body = "strict_env";
      description = "Enable strict mode (set -euo pipefail)";
    };
    "log_status" = {
      prefix = "log_status";
      body = "log_status \"$1\"";
      description = "Log a status message";
    };
    "log_error" = {
      prefix = "log_error";
      body = "log_error \"$1\"";
      description = "Log an error message";
    };
    "has" = {
      prefix = "has";
      body = "has $1";
      description = "Check if a command exists";
    };
    "envrc template" = {
      prefix = "envrc";
      body = [
        "# shellcheck shell=bash"
        "watch_file flake.nix"
        "watch_file flake.lock"
        ""
        "if has nix; then"
        "  use flake"
        "fi"
        "$0"
      ];
      description = "Standard .envrc template with flake support";
    };
    # Custom direnv modules
    "from_op" = {
      prefix = "from_op";
      body = "from_op $1=\"op://$2/$3/$4\"";
      description = "Load secret from 1Password (vault/item/field)";
    };
    "from_op file" = {
      prefix = "from_op_file";
      body = "from_op $1";
      description = "Load secrets from 1Password env file";
    };
    "from_op verbose" = {
      prefix = "from_op_verbose";
      body = "from_op --verbose $1=\"op://$2/$3/$4\"";
      description = "Load secret from 1Password with logging";
    };
    "use_sops" = {
      prefix = "use_sops";
      body = "use_sops $0";
      description = "Load secrets from SOPS-encrypted file (default: secrets.yaml)";
    };
    "from_lpass" = {
      prefix = "from_lpass";
      body = "from_lpass $1=\"$2\"";
      description = "Load secret from LastPass (var=secret_name)";
    };
    "from_lpass file" = {
      prefix = "from_lpass_file";
      body = "from_lpass $1";
      description = "Load secrets from LastPass env file";
    };
    "from_lpass verbose" = {
      prefix = "from_lpass_verbose";
      body = "from_lpass --verbose $1=\"$2\"";
      description = "Load secret from LastPass with logging";
    };
    "envrc with secrets" = {
      prefix = "envrc_secrets";
      body = [
        "# shellcheck shell=bash"
        "watch_file flake.nix"
        "watch_file flake.lock"
        ""
        "if has nix; then"
        "  use flake"
        "fi"
        ""
        "# Load secrets from 1Password"
        "from_op --verbose \\"
        "  $1=\"op://$2/$3/$4\""
        "$0"
      ];
      description = ".envrc template with flake and 1Password secrets";
    };
  };
}
