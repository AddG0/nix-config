# Fix gcloud interactive shell on NixOS (hardcoded /bin/bash).
_: _final: prev: {
  google-cloud-sdk = prev.google-cloud-sdk.overrideAttrs (old: {
    postInstall =
      (old.postInstall or "")
      + ''
        substituteInPlace $out/google-cloud-sdk/lib/googlecloudsdk/command_lib/interactive/coshell.py \
          --replace-fail "SHELL_PATH = '/bin/bash'" "SHELL_PATH = '${prev.bash}/bin/bash'"
        substituteInPlace $out/google-cloud-sdk/lib/googlecloudsdk/core/execution_utils.py \
          --replace-fail "shells = ['/bin/bash', '/bin/sh']" "shells = ['${prev.bash}/bin/bash', '/bin/sh']"
      '';
  });
}
