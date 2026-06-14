{
  # DAP FRAMEWORK + keymaps. The language adapters live with their language:
  # rust (codelldb) in ./languages/rust.nix, go (delve) in go.nix, python
  # (debugpy) in python.nix, and java via nvim-jdtls in java.nix.
  plugins = {
    dap.enable = true;
    dap-ui.enable = true;
    dap-virtual-text.enable = true;
  };

  # LazyVim-style debug keymaps.
  keymaps = [
    {
      mode = "n";
      key = "<leader>db";
      action.__raw = "function() require('dap').toggle_breakpoint() end";
      options.desc = "Toggle breakpoint";
    }
    {
      mode = "n";
      key = "<leader>dB";
      action.__raw = ''function() require('dap').set_breakpoint(vim.fn.input("Breakpoint condition: ")) end'';
      options.desc = "Conditional breakpoint";
    }
    {
      mode = "n";
      key = "<leader>dc";
      action.__raw = "function() require('dap').continue() end";
      options.desc = "Continue";
    }
    {
      mode = "n";
      key = "<leader>dC";
      action.__raw = "function() require('dap').run_to_cursor() end";
      options.desc = "Run to cursor";
    }
    {
      mode = "n";
      key = "<leader>di";
      action.__raw = "function() require('dap').step_into() end";
      options.desc = "Step into";
    }
    {
      mode = "n";
      key = "<leader>do";
      action.__raw = "function() require('dap').step_out() end";
      options.desc = "Step out";
    }
    {
      mode = "n";
      key = "<leader>dO";
      action.__raw = "function() require('dap').step_over() end";
      options.desc = "Step over";
    }
    {
      mode = "n";
      key = "<leader>dt";
      action.__raw = "function() require('dap').terminate() end";
      options.desc = "Terminate";
    }
    {
      mode = "n";
      key = "<leader>dr";
      action.__raw = "function() require('dap').repl.toggle() end";
      options.desc = "Toggle REPL";
    }
    {
      mode = "n";
      key = "<leader>du";
      action.__raw = "function() require('dapui').toggle() end";
      options.desc = "Toggle DAP UI";
    }
    {
      mode = ["n" "v"];
      key = "<leader>de";
      action.__raw = "function() require('dapui').eval() end";
      options.desc = "Eval";
    }
  ];
}
