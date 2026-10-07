{
  aiProxy,
  codex,
  pkgs,
}: let
  launcher = pkgs.writeShellScript "codex" ''
    if ${aiProxy}/bin/ai-proxy ready general; then
      exec ${codex}/bin/codex --config 'model_provider="ai-proxy"' "$@"
    fi
    exec ${codex}/bin/codex "$@"
  '';
in
  pkgs.symlinkJoin {
    name = "codex-${codex.version}";
    inherit (codex) version;
    paths = [codex];
    postBuild = ''
      rm "$out/bin/codex"
      ln -s ${launcher} "$out/bin/codex"
    '';
    meta.mainProgram = "codex";
  }
