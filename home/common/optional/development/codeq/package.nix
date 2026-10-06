# The codeq script with every analyser on its PATH; shared by default.nix and tests.nix.
{
  lib,
  stdenv,
  writeShellApplication,
  writeTextFile,
  symlinkJoin,
  coreutils,
  findutils,
  gnugrep,
  gnused,
  gawk,
  git,
  python3,
  python3Packages,
  tokei,
  graphviz,
  jdk,
  customPkgs,
}: let
  script = writeShellApplication {
    name = "codeq";
    runtimeInputs =
      [
        coreutils
        findutils
        gnugrep
        gnused
        gawk
        git
        python3
        tokei
        python3Packages.lizard
        graphviz
        jdk
        customPkgs.pmd
        customPkgs.ck
        customPkgs.spotbugs
      ]
      # sqry publishes Linux binaries only; cycles/overview report that elsewhere.
      ++ lib.optional (lib.meta.availableOn stdenv.hostPlatform customPkgs.sqry) customPkgs.sqry;
    text =
      ''
        CODEQ_LIB=${./lib}
      ''
      + builtins.readFile ./codeq.sh;
  };

  zshCompletion = writeTextFile {
    name = "codeq-zsh-completion";
    destination = "/share/zsh/site-functions/_codeq";
    text = builtins.readFile ./_codeq;
  };

  nuCompletion = writeTextFile {
    name = "codeq-nu-completion";
    destination = "/share/nushell/vendor/autoload/codeq.nu";
    text = builtins.readFile ./codeq.nu;
  };
in
  symlinkJoin {
    name = "codeq";
    paths = [script zshCompletion nuCompletion];
    meta.mainProgram = "codeq";
  }
