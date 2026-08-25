{
  # AI assistance, two layers:
  #   sidekick.nvim  — Claude Code CLI in-editor (reuses the subscription, no API
  #                    tokens). NES stays off: it needs the Copilot LSP we don't
  #                    run, and enabling it fails a build-time assertion.
  #   codecompanion  — chat/inline over the Anthropic API, auth via the
  #                    ANTHROPIC_API_KEY that secrets/ai.nix exports into zsh.
  plugins = {
    sidekick = {
      enable = true;
      # nixvim exposes no `dependencies` option for sidekick (despite its docs);
      # the claude-code CLI is already on PATH via home.packages.
      settings.nes.enabled = false;
    };

    codecompanion = {
      enable = true;
      settings = {
        strategies = {
          chat.adapter = "anthropic";
          inline.adapter = "anthropic";
          cmd.adapter = "anthropic";
        };
        # Pin the current Claude model; the anthropic adapter reads
        # ANTHROPIC_API_KEY from the environment on its own.
        adapters.anthropic.__raw = ''
          function()
            return require("codecompanion.adapters").extend("anthropic", {
              schema = { model = { default = "claude-opus-4-8" } },
            })
          end
        '';
      };
    };
  };

  keymaps = [
    # ── sidekick: Claude Code CLI ──
    {
      mode = "n";
      key = "<leader>aa";
      action.__raw = "function() require('sidekick.cli').toggle() end";
      options.desc = "Toggle AI CLI";
    }
    {
      mode = "n";
      key = "<leader>as";
      action.__raw = "function() require('sidekick.cli').select() end";
      options.desc = "Select AI CLI";
    }
    {
      mode = "n";
      key = "<leader>ad";
      action.__raw = "function() require('sidekick.cli').close() end";
      options.desc = "Close AI CLI";
    }
    {
      mode = "n";
      key = "<leader>ap";
      action.__raw = "function() require('sidekick.cli').prompt() end";
      options.desc = "AI prompt picker";
    }
    {
      mode = "n";
      key = "<leader>at";
      action.__raw = "function() require('sidekick.cli').send({ msg = '{this}' }) end";
      options.desc = "Send cursor context to CLI";
    }
    {
      mode = "n";
      key = "<leader>af";
      action.__raw = "function() require('sidekick.cli').send({ msg = '{file}' }) end";
      options.desc = "Send file to CLI";
    }
    {
      mode = "x";
      key = "<leader>av";
      action.__raw = "function() require('sidekick.cli').send({ msg = '{selection}' }) end";
      options.desc = "Send selection to CLI";
    }

    # ── codecompanion: in-editor chat/inline (grouped under <leader>ac, away
    # from sidekick's flat <leader>a* leaves, so which-key shows them as a
    # distinct submenu) ──
    {
      mode = ["n" "x"];
      key = "<leader>acc";
      action = "<cmd>CodeCompanionChat Toggle<cr>";
      options.desc = "Toggle chat";
    }
    {
      mode = ["n" "x"];
      key = "<leader>acx";
      action = "<cmd>CodeCompanionActions<cr>";
      options.desc = "Action palette";
    }
    # Leaves the cmdline open so you type the instruction (e.g. "refactor").
    {
      mode = ["n" "x"];
      key = "<leader>aci";
      action = ":CodeCompanion ";
      options.desc = "Inline prompt";
    }
    {
      mode = "x";
      key = "<leader>ace";
      action = "<cmd>CodeCompanionChat Add<cr>";
      options.desc = "Add selection to chat";
    }
  ];
}
