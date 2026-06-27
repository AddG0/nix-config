# klnav: tail matching pods (via stern) into lnav, one file per
# namespace/pod/container so each is a separately toggleable source. The tailing
# logic lives in klnav.sh; this derivation bundles it with a zsh completion.
{
  symlinkJoin,
  writeShellApplication,
  runCommand,
  stern,
  lnav,
  gawk,
  coreutils,
  procps,
  gnused,
}: let
  script = writeShellApplication {
    name = "klnav";
    runtimeInputs = [stern lnav gawk coreutils procps];
    text = builtins.readFile ./klnav.sh;
  };

  # Reuse stern's own cobra completion, rewritten to drive `klnav`: rename
  # _stern→_klnav so it can't clash with stern's, and force the dynamic lookup
  # to call the real `stern __complete` (cobra emits `${words[1]} __complete`,
  # which would otherwise re-enter the klnav wrapper). klnav forwards its args to
  # stern, so stern's completions (pod queries, -n, -l, flags) apply verbatim.
  zshCompletion = runCommand "klnav-zsh-completion" {} ''
    mkdir -p $out/share/zsh/site-functions
    ${stern}/bin/stern --completion zsh \
      | ${gnused}/bin/sed \
          -e 's/_stern/_klnav/g' \
          -e 's/\bstern\b/klnav/g' \
          -e 's/\''${words\[1\]} __complete/stern __complete/' \
      > $out/share/zsh/site-functions/_klnav
  '';
in
  symlinkJoin {
    name = "klnav";
    paths = [script zshCompletion];
  }
