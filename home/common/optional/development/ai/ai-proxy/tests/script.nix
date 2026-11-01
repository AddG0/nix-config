{
  harness,
  pkgs,
  lib,
  ...
}: let
  mockCurl = pkgs.writeShellScriptBin "curl" ''
    printf '%s\n' "$*" >>"$CURL_LOG"
    [[ ''${CURL_RESULT:-200} != fail ]] || exit 1
    printf '%s' "''${CURL_RESULT:-200}"
  '';
  mockFlock = pkgs.writeShellScriptBin "flock" "exit 0";
  fakeCodex =
    pkgs.writeShellScriptBin "codex" ''
      printf '%s\n' "$@"
    ''
    // {version = "test";};
  wrapper = ready:
    import ../codex-wrapper.nix {
      inherit pkgs;
      codex = fakeCodex;
      aiProxy = pkgs.writeShellScriptBin "ai-proxy" (
        if ready
        then "exit 0"
        else "exit 1"
      );
    };
in
  harness.bats "codex-ai-proxy-fallback-test" [./ai-proxy.bats] {
    nativeBuildInputs = [pkgs.jq];
    readyCodex = "${wrapper true}/bin/codex";
    unreadyCodex = "${wrapper false}/bin/codex";
    aiProxy = ../ai-proxy.sh;
    stubPath = lib.makeBinPath [mockCurl mockFlock];
  }
