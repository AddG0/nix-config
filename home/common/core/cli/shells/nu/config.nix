{pkgs, ...}: {
  programs.nushell.extraConfig = ''
    # Load Catppuccin Mocha Theme from Nix store
    # ----------------------------------------------------------------------------
    source ${pkgs.themes.catppuccin.nushell}/share/nu-themes/catppuccin_mocha.nu

    # General Settings
    # ----------------------------------------------------------------------------
    $env.config = ($env.config | upsert show_banner false)
    $env.config = ($env.config | upsert edit_mode vi) # or "emacs"
    $env.config = ($env.config | upsert use_ansi_coloring true)
    $env.config = ($env.config | upsert render_right_prompt_on_last_line false)

    # Completion Settings
    # ----------------------------------------------------------------------------
    $env.config = ($env.config | upsert completions {
      case_sensitive: false
      quick: true
      partial: true
      algorithm: "fuzzy"
    })

    # History Settings
    # ----------------------------------------------------------------------------
    $env.config = ($env.config | upsert history {
      max_size: 100000
      sync_on_enter: true
      file_format: "sqlite"
      isolation: false
    })

    # Cursor Shapes
    # ----------------------------------------------------------------------------
    $env.config = ($env.config | upsert cursor_shape {
      emacs: line
      vi_insert: line
      vi_normal: block
    })

    # Table Display
    # ----------------------------------------------------------------------------
    $env.config = ($env.config | upsert table {
      mode: rounded
      index_mode: always
      show_empty: true
      padding: { left: 1, right: 1 }
      trim: {
        methodology: wrapping
        wrapping_try_keep_words: true
      }
    })

    # Explore Command Settings (for interactive data exploration)
    # ----------------------------------------------------------------------------
    $env.config = ($env.config | upsert explore {
      status_bar_background: {fg: "#1D1F21", bg: "#C4C9C6"}
      command_bar_text: {fg: "#C4C9C6"}
      highlight: {fg: "black", bg: "yellow"}
      status: {
        warn: {fg: "yellow"}
        error: {fg: "red"}
        info: {fg: "blue"}
      }
      table: {
        split_line: {fg: "#404040"}
        selected_cell: {bg: "light_blue"}
        selected_row: {bg: "dark_gray"}
        selected_column: {bg: "dark_gray"}
      }
    })

    # Hooks
    # ----------------------------------------------------------------------------
    $env.config = ($env.config | upsert hooks {
      pre_prompt: [{ null }]
      env_change: {
        PWD: [{|before, after| null }]
      }
      display_output: "if (term size).columns >= 100 { table -e } else { table }"
      command_not_found: { null }
    })

    # ============================================================================
    # Custom Commands
    # ============================================================================

    # Quick directory navigation with ls
    def --env cdl [path?: string] {
      if ($path == null) {
        cd ~
      } else {
        cd $path
      }
      ls
    }

    # Make directory and cd into it
    def --env mkcd [name: string] {
      mkdir $name
      cd $name
    }

    # Create a backup of a file
    def backup [file: string] {
      let timestamp = (date now | format date "%Y%m%d_%H%M%S")
      cp $file $"($file).backup_($timestamp)"
      print $"Backup created: ($file).backup_($timestamp)"
    }

    # ============================================================================
    # Optional: Load community completions from Nix store
    # ============================================================================
    # Uncomment the completions you want to use:
    #
    # source ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/git/git-completions.nu
    # source ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/cargo/cargo-completions.nu
    # source ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/docker/docker-completions.nu
    # source ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/nix/nix-completions.nu
    # source ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/make/make-completions.nu
    # source ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/npm/npm-completions.nu
    # source ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/kubectl/kubectl-completions.nu
  '';
}
