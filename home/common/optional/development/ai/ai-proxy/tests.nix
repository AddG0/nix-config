# Auto-discovered and wired into `nix flake check` by checks/module-tests.nix.
{pkgs, ...}: let
  mockCurl = pkgs.writeShellScriptBin "curl" ''
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
    import ./codex-wrapper.nix {
      inherit pkgs;
      codex = fakeCodex;
      aiProxy = pkgs.writeShellScriptBin "ai-proxy" (
        if ready
        then "exit 0"
        else "exit 1"
      );
    };
in
  pkgs.runCommand "codex-ai-proxy-fallback-test" {
    nativeBuildInputs = [pkgs.bash pkgs.coreutils pkgs.jq];
  } ''
    ${wrapper true}/bin/codex exec prompt >reachable
    grep -qxF -- '--config' reachable
    grep -qxF -- 'model_provider="ai-proxy"' reachable
    grep -qxF -- 'exec' reachable
    grep -qxF -- 'prompt' reachable

    ${wrapper false}/bin/codex exec prompt >unreachable
    if grep -qF -- 'model_provider=' unreachable; then
      echo "FAIL: unreachable proxy still selected the proxy provider" >&2
      cat unreachable >&2
      exit 1
    fi
    grep -qxF -- 'exec' unreachable
    grep -qxF -- 'prompt' unreachable

    export PATH=${mockCurl}/bin:${mockFlock}/bin:$PATH
    export XDG_STATE_HOME="$PWD/state"
    export AI_PROXY_ISSUER=https://auth.example
    export AI_PROXY_CLIENT_ID=test
    export AI_PROXY_URL=https://proxy.example
    export AI_PROXY_CLAUDE_URL=https://claude.example
    export AI_PROXY_SCOPE=test
    mkdir -p "$XDG_STATE_HOME/ai-proxy"
    printf '%s' '{"access_token":"test","expires_at":4102444800}' >"$XDG_STATE_HOME/ai-proxy/token.json"

    bash ${./ai-proxy.sh} ready general
    if CURL_RESULT=fail bash ${./ai-proxy.sh} ready general; then
      echo "FAIL: unreachable proxy reported ready" >&2
      exit 1
    fi

    rm "$XDG_STATE_HOME/ai-proxy/token.json"
    if bash ${./ai-proxy.sh} ready general; then
      echo "FAIL: logged-out proxy reported ready" >&2
      exit 1
    fi

    touch "$out"
  ''
