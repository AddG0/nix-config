{
  pkgs,
  lib,
  ...
}: let
  jdtlsBin = "${pkgs.jdt-language-server}/bin/jdtls";
  javaDebug = pkgs.vscode-extensions.vscjava.vscode-java-debug;
  javaTest = pkgs.vscode-extensions.vscjava.vscode-java-test;
  # Lombok is distributed as a prebuilt jar, so pkgs.lombok.src IS the jar.
  # jdtls needs it as a -javaagent or it flags false errors for Lombok-generated
  # members (@Getter/@Data/@Builder etc.).
  lombokJar = pkgs.lombok.src;
  # Real GRADLE_HOME inside the nixpkgs gradle wrapper (bin/, lib/, gradle.properties).
  gradleHome = "${pkgs.gradle}/libexec/gradle";
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
    # nvim-jdtls' sha1() (used by wipe_data_and_restart) shells out to bare
    # `python3`, which forced a python onto nvim's PATH where it shadowed
    # basedpyright's project interpreter. Absolutize it so none is needed on PATH.
    package = pkgs.vimPlugins.nvim-jdtls.overrideAttrs (old: {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace lua/jdtls/setup.lua \
            --replace-fail 'vim.fn.executable("python3") == 1 and "python3" or "python"' \
              '"${lib.getExe' pkgs.python3Minimal "python3"}"'
        '';
    });
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
      # Without a checked-in wrapper Buildship falls back to its bundled Gradle 8.9,
      # too old for our Spring Boot 4 services (need ≥8.14) → import fails, no
      # classpath. Pin the nixpkgs Gradle (9.5.1) as the floor; a project wrapper
      # still wins (wrapper.enabled defaults true). Register both JDKs as toolchain
      # candidates so a project pinning either a Java 21 or 25 toolchain resolves
      # without foojay auto-download (blocked in the nix sandbox).
      settings.java.import.gradle = {
        home = gradleHome;
        java.home = "${pkgs.jdk21.home}";
        jvmArguments = "-Dorg.gradle.java.installations.paths=${pkgs.jdk21.home},${pkgs.jdk25.home}";
      };
      # jdtls' "interactive" default wants to prompt before re-importing on a
      # build-file change, but nvim-jdtls surfaces no prompt UI — so it silently
      # never syncs, and a dependency added after the first import (e.g. gitlab4j)
      # stays off the classpath until the workspace is wiped by hand.
      settings.java.configuration.updateBuildConfiguration = "automatic";
      # Default JavaSE-25 (current work targets it); JavaSE-21 kept for older
      # projects. Independent of the jdtls server JVM, which stays jdk21.
      settings.java.configuration.runtimes = [
        {
          name = "JavaSE-25";
          path = "${pkgs.jdk25.home}";
          default = true;
        }
        {
          name = "JavaSE-21";
          path = "${pkgs.jdk21.home}";
        }
      ];
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

  # jdtls JVM runtime.
  extraPackages = [pkgs.jdk21];
}
