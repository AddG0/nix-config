# temporal-cli ships completion via `temporal completion <shell>` but doesn't
# install the scripts into the package, so shells never autoload them. Generate
# and place them in the standard locations home-manager/NixOS picks up.
_: _final: prev: {
  temporal-cli = prev.temporal-cli.overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or []) ++ [prev.installShellFiles];
    postInstall =
      (old.postInstall or "")
      + ''
        installShellCompletion --cmd temporal \
          --bash <($out/bin/temporal completion bash) \
          --zsh <($out/bin/temporal completion zsh) \
          --fish <($out/bin/temporal completion fish)
      '';
  });
}
