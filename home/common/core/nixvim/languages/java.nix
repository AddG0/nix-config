{pkgs, ...}: let
  jdtlsBin = "${pkgs.jdt-language-server}/bin/jdtls";
  javaDebug = pkgs.vscode-extensions.vscjava.vscode-java-debug;
  javaTest = pkgs.vscode-extensions.vscjava.vscode-java-test;
  # Lombok is distributed as a prebuilt jar, so pkgs.lombok.src IS the jar.
  # jdtls needs it as a -javaagent or it flags false errors for Lombok-generated
  # members (@Getter/@Data/@Builder etc.).
  lombokJar = pkgs.lombok.src;
in {
  # Java via nvim-jdtls — the rich jdtls integration (NOT the lspconfig jdtls,
  # which is why no `lsp.servers.jdtls` exists). Feeding it the java-debug +
  # java-test bundle jars (from nixpkgs) makes nvim-jdtls auto-register a Java
  # debug adapter with nvim-dap (../dap.nix) and wire the JUnit test runner.
  # nvim-jdtls starts per-buffer on the `java` filetype; jdk21 is its runtime.
  #
  # Still not covered: Spring Boot (separate language server, no nvim equiv).
  plugins.jdtls = {
    enable = true;
    settings = {
      # jdtls reprocesses on every change before it can answer position queries
      # (gd/grr/gri), which is why nav lags ~a second right after editing. It's a
      # heavy server; the Eclipse-recommended JVM tuning (bigger heap + parallel
      # GC) cuts that reindex time — reduces the lag, doesn't eliminate it.
      cmd = [
        jdtlsBin
        "--jvm-arg=-javaagent:${lombokJar}"
        "--jvm-arg=-Xmx2g"
        "--jvm-arg=-XX:+UseParallelGC"
        "--jvm-arg=-XX:GCTimeRatio=4"
        "--jvm-arg=-XX:AdaptiveSizePolicyWeight=90"
        "--jvm-arg=-Dsun.zip.disableMemoryMapping=true"
      ];
      init_options.bundles.__raw = ''
        vim.list_extend(
          vim.fn.glob("${javaDebug}/share/vscode/extensions/vscjava.vscode-java-debug/server/com.microsoft.java.debug.plugin-*.jar", true, true),
          vim.fn.glob("${javaTest}/share/vscode/extensions/vscjava.vscode-java-test/server/*.jar", true, true)
        )
      '';
    };
  };
  # jdtls-only maps, buffer-local on jdtls buffers — so <leader>co overrides the
  # generic one in ../lsp.nix without a global collision.
  autoGroups.jdtls-keymaps.clear = true;
  autoCmd = [
    {
      event = "LspAttach";
      group = "jdtls-keymaps";
      desc = "jdtls buffer-local keymaps";
      callback.__raw = ''
        function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if not client or client.name ~= "jdtls" then return end
          local jdtls = require("jdtls")
          local function map(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, { buffer = args.buf, desc = desc })
          end
          map("n", "<leader>co", jdtls.organize_imports, "Organize Imports")
          map("n", "<leader>cxv", jdtls.extract_variable_all, "Extract Variable")
          map("n", "<leader>cxc", jdtls.extract_constant, "Extract Constant")
          map("n", "<leader>cgs", jdtls.super_implementation, "Goto Super")
          map("x", "<leader>cxm", function() jdtls.extract_method(true) end, "Extract Method")
          map("x", "<leader>cxv", function() jdtls.extract_variable_all(true) end, "Extract Variable")
          map("x", "<leader>cxc", function() jdtls.extract_constant(true) end, "Extract Constant")
        end
      '';
    }
  ];

  extraPackages = [pkgs.jdk21];
}
