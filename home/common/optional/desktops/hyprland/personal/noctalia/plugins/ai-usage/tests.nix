# Auto-discovered and wired into `nix flake check` by checks/module-tests.nix.
{pkgs, ...}:
pkgs.runCommand "ai-usage-plugin-tests" {nativeBuildInputs = [pkgs.luau pkgs.python3 pkgs.jq];} ''
  {
    echo 'local SERVICE_SRC = [=====['
    cat ${./service.luau}
    echo ']=====]'
    cat ${./service_test.luau}
  } > combined.luau
  luau combined.luau

  python3 ${./plugin_test.py} ${./plugin.toml}
  python3 ${./report_test.py} ${./report.jq}
  touch $out
''
