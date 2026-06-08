{pkgs, ...}: let
  # codelldb adapter binary shipped inside the vscode-lldb extension.
  codelldb = "${pkgs.vscode-extensions.vadimcn.vscode-lldb}/share/vscode/extensions/vadimcn.vscode-lldb/adapter/codelldb";
in {
  programs.nixvim = {
    plugins.lsp.servers.rust_analyzer = {
      # rust-analyzer needs cargo + rustc on PATH to analyze projects; let
      # nixvim provide them (silences the install warnings too).
      enable = true;
      installCargo = true;
      installRustc = true;
    };
    plugins.conform-nvim.settings.formatters_by_ft.rust = ["rustfmt"];

    # Debugging via codelldb (the DAP framework lives in ../dap.nix).
    plugins.dap = {
      adapters.servers.codelldb = {
        port = "\${port}";
        executable = {
          command = codelldb;
          args = ["--port" "\${port}"];
        };
      };
      configurations.rust = [
        {
          name = "Launch";
          type = "codelldb";
          request = "launch";
          program.__raw = ''
            function()
              return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/target/debug/", "file")
            end
          '';
          cwd = "\${workspaceFolder}";
          stopOnEntry = false;
        }
      ];
    };

    extraPackages = [pkgs.rustfmt]; # ≠ rust-analyzer
  };
}
