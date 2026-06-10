{
  # In-editor test runner FRAMEWORK (neotest). Mirrors lsp.nix: this module owns
  # only the language-agnostic plugin + `<leader>t*` keymaps (grouped as "test"
  # in which-key, ui.nix). Each language wires its own adapter in
  # ./languages/<lang>.nix (e.g. neotest.adapters.python.enable), the same way
  # it owns its LSP server / formatter / linter / DAP.
  #
  # Results show inline next to each test and in the summary panel. The actual
  # test tools (pytest, cargo, gradle, …) come from each project, not from here.
  programs.nixvim.plugins.neotest.enable = true;

  programs.nixvim.keymaps = [
    {
      mode = "n";
      key = "<leader>tt";
      action.__raw = "function() require('neotest').run.run(vim.fn.expand('%')) end";
      options.desc = "Run file";
    }
    {
      mode = "n";
      key = "<leader>tT";
      action.__raw = "function() require('neotest').run.run(vim.uv.cwd()) end";
      options.desc = "Run all test files";
    }
    {
      mode = "n";
      key = "<leader>tr";
      action.__raw = "function() require('neotest').run.run() end";
      options.desc = "Run nearest";
    }
    {
      mode = "n";
      key = "<leader>tl";
      action.__raw = "function() require('neotest').run.run_last() end";
      options.desc = "Run last";
    }
    {
      mode = "n";
      key = "<leader>ts";
      action.__raw = "function() require('neotest').summary.toggle() end";
      options.desc = "Toggle summary";
    }
    {
      mode = "n";
      key = "<leader>to";
      action.__raw = "function() require('neotest').output.open({ enter = true, auto_close = true }) end";
      options.desc = "Show output";
    }
    {
      mode = "n";
      key = "<leader>tO";
      action.__raw = "function() require('neotest').output_panel.toggle() end";
      options.desc = "Toggle output panel";
    }
    {
      mode = "n";
      key = "<leader>tS";
      action.__raw = "function() require('neotest').run.stop() end";
      options.desc = "Stop";
    }
    {
      mode = "n";
      key = "<leader>tw";
      action.__raw = "function() require('neotest').watch.toggle(vim.fn.expand('%')) end";
      options.desc = "Toggle watch";
    }
    # Debug the nearest test through nvim-dap (../dap.nix).
    {
      mode = "n";
      key = "<leader>td";
      action.__raw = "function() require('neotest').run.run({ strategy = 'dap' }) end";
      options.desc = "Debug nearest";
    }
  ];
}
