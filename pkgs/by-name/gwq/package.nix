{
  lib,
  stdenv,
  buildGoModule,
  fetchFromGitHub,
  git,
  installShellFiles,
  writableTmpDirAsHomeHook,
}:
buildGoModule rec {
  pname = "gwq";
  version = "0.1.1";

  src = fetchFromGitHub {
    owner = "d-kuro";
    repo = "gwq";
    rev = "v${version}";
    hash = "sha256-MfCYFbODWnfPxx+6sLlcMT6tqghgILHB13+ccYqVjBA=";
  };

  vendorHash = "sha256-4K01Xf1EXl/NVX1loQ76l1bW8QglBAQdvlZSo7J4NPI=";

  nativeBuildInputs = [installShellFiles];

  # Tests `git init` and read config from $HOME.
  nativeCheckInputs = [git writableTmpDirAsHomeHook];

  ldflags = ["-s" "-w"];

  postInstall = lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
    installShellCompletion --cmd gwq \
      --bash <($out/bin/gwq completion bash) \
      --zsh <($out/bin/gwq completion zsh) \
      --fish <($out/bin/gwq completion fish)
  '';

  meta = {
    description = "Git worktree manager modeled on ghq — \"ghq for worktrees\"";
    homepage = "https://github.com/d-kuro/gwq";
    license = lib.licenses.mit;
    mainProgram = "gwq";
  };
}
