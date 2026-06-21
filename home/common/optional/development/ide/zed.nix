# Zed config mirrors the nixvim / vscode / jetbrains setups:
#   - Catppuccin Mocha + JetBrains Mono everywhere (see vscode catppuccin.nix,
#     jetbrains theme, nixvim ui.nix)
#   - vim mode (nixvim is the daily driver; vscode runs vscodevim)
#   - format-on-save + autosave, relative line numbers (editor-settings.nix)
#   - the same LSP/formatter toolchain nixvim installs per language, supplied on
#     PATH via extraPackages so Zed uses the nix binaries instead of downloading
#     dynamically-linked ones that don't run on NixOS.
#
# settings.json stays the home-manager default (mutable): the nix attrs below are
# deep-merged over Zed's live file on every activation, so they're enforced while
# Zed can still persist transient UI state.
{
  pkgs,
  self,
  osConfig,
  ...
}: let
  # nixd evaluates these lazily to learn the option set, giving option/package
  # hover docs in every nix repo. Mirrors nixvim/languages/nix.nix exactly.
  flake = ''builtins.getFlake "${self}"'';
  host = osConfig.networking.hostName;
in {
  programs.zed-editor = {
    enable = true;

    # Language extensions. Zed bundles Rust/Go/Python/TS/JS/JSON/YAML/Markdown/
    # Bash/CSS; these add the rest of the stack the other editors cover.
    extensions = [
      "catppuccin"
      "catppuccin-icons"
      "nix"
      "toml"
      "dockerfile"
      "docker-compose"
      "make"
      "html"
      "proto"
      "helm"
      "terraform"
      "kotlin"
      "java"
      "lua"
      "sql"
      "csv"
      "scss"
      "vue"
      "xml"
      "just"
      "log"
      "git-firefly"
    ];

    # LSP servers + formatters on PATH, matching the nixvim per-language stacks.
    extraPackages = with pkgs; [
      nixd
      alejandra
      gopls
      gotools # goimports
      rust-analyzer
      basedpyright
      ruff
      lua-language-server
      stylua
      yaml-language-server
      taplo # toml
      marksman # markdown
      vscode-langservers-extracted # html/css/json/eslint
      tailwindcss-language-server
      dockerfile-language-server
      bash-language-server
      shellcheck
      shfmt
      kotlin-language-server
      jdt-language-server # java
      helm-ls
      terraform-ls
      buf # proto
      prettierd
    ];

    userSettings = {
      # Theme + fonts are owned by the stylix zed target (catppuccin-mocha
      # base16 scheme, stylix monospace font). These extras don't conflict.
      icon_theme = "Catppuccin Mocha";
      buffer_font_features.calt = true; # ligatures
      buffer_line_height.custom = 1.5;

      # --- Vim ---
      vim_mode = true;
      cursor_blink = true;
      relative_line_numbers = true;

      # --- Editor behaviour (editor-settings.nix parity) ---
      autosave.after_delay.milliseconds = 1000;
      format_on_save = "on";
      remove_trailing_whitespace_on_save = true;
      ensure_final_newline_on_save = true;
      soft_wrap = "none";
      show_whitespaces = "selection";
      minimap.show = "never";
      project_panel.dock = "left";
      scroll_beyond_last_line = "one_page";
      use_smartcase_search = true;
      tab_size = 2;
      inlay_hints.enabled = true;
      indent_guides = {
        enabled = true;
        coloring = "indent_aware";
      };
      gutter.code_actions = true;

      # --- AI ---
      # Edit-prediction provider left at Zed's default (Zeta). Claude in the agent panel.
      agent.default_model = {
        provider = "anthropic";
        model = "claude-sonnet-4-latest";
      };

      # --- Terminal ---
      terminal = {
        font_family = "JetBrains Mono";
        copy_on_select = true;
      };

      # --- Managed by Nix: no self-update / telemetry ---
      auto_update = false;
      telemetry = {
        diagnostics = false;
        metrics = false;
      };

      # --- File scanning (search.exclude / files.exclude parity) ---
      file_scan_exclusions = [
        "**/.git"
        "**/.direnv"
        "**/.devenv"
        "**/result"
        "**/node_modules"
        "**/__pycache__"
        "**/.gradle"
        "**/build"
        "**/target"
        "**/.pre-commit-config.yaml"
        "**/dump.rdb"
      ];

      # --- Language servers ---
      lsp = {
        # nixd option/package hover, resolved against this flake (see nix.nix).
        nixd.settings.nixd = {
          nixpkgs.expr = "import (${flake}).inputs.nixpkgs { }";
          formatting.command = ["alejandra"];
          options = {
            nixos.expr = "(${flake}).nixosConfigurations.${host}.options";
            "home-manager".expr = "(${flake}).nixosConfigurations.${host}.options.home-manager.users.type.getSubOptions []";
          };
        };
      };

      languages = {
        Nix.language_servers = ["nixd" "!nil"];
        Python = {
          language_servers = ["basedpyright" "ruff"];
          formatter.language_server.name = "ruff";
        };
        Go.formatter.language_server.name = "gopls";
      };
    };

    # vim-style leader maps echoing the nixvim Snacks pickers / LSP keymaps.
    userKeymaps = [
      {
        context = "Editor && vim_mode == normal && !menu";
        bindings = {
          "space space" = "file_finder::Toggle";
          "space f g" = "pane::DeploySearch";
          "space e" = "workspace::ToggleLeftDock";
          "g d" = "editor::GoToDefinition";
          "g r" = "editor::FindAllReferences";
          "g I" = "editor::GoToImplementation";
          "g y" = "editor::GoToTypeDefinition";
          "space c a" = "editor::ToggleCodeActions";
          "space c r" = "editor::Rename";
          "space c f" = "editor::Format";
        };
      }
    ];
  };
}
