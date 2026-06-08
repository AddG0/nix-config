{pkgs, ...}: let
  jdtlsBin = "${pkgs.jdt-language-server}/bin/jdtls";
  javaDebug = pkgs.vscode-extensions.vscjava.vscode-java-debug;
  javaTest = pkgs.vscode-extensions.vscjava.vscode-java-test;
in {
  # Java via nvim-jdtls — the rich jdtls integration (NOT the lspconfig jdtls,
  # which is why no `lsp.servers.jdtls` exists). Feeding it the java-debug +
  # java-test bundle jars (from nixpkgs) makes nvim-jdtls auto-register a Java
  # debug adapter with nvim-dap (../dap.nix) and wire the JUnit test runner.
  # nvim-jdtls starts per-buffer on the `java` filetype; jdk21 is its runtime.
  #
  # Still not covered: Spring Boot (separate language server, no nvim equiv).
  programs.nixvim = {
    plugins.jdtls = {
      enable = true;
      settings = {
        cmd = [jdtlsBin];
        init_options.bundles.__raw = ''
          vim.list_extend(
            vim.fn.glob("${javaDebug}/share/vscode/extensions/vscjava.vscode-java-debug/server/com.microsoft.java.debug.plugin-*.jar", true, true),
            vim.fn.glob("${javaTest}/share/vscode/extensions/vscjava.vscode-java-test/server/*.jar", true, true)
          )
        '';
      };
    };
    extraPackages = [pkgs.jdk21];
  };
}
