{
  lib,
  stdenv,
  buildGoModule,
  coreutils,
  fetchFromGitHub,
  installShellFiles,
  versionCheckHook,
  writableTmpDirAsHomeHook,
}:
buildGoModule rec {
  pname = "bootdev-cli";
  version = "1.32.2";

  src = fetchFromGitHub {
    owner = "bootdotdev";
    repo = "bootdev";
    tag = "v${version}";
    hash = "sha256-GD/VD4NCCC4ptf37T/JfKB7m8GabhtC8NCLeeX+DfkY=";
  };

  vendorHash = "sha256-ZDioEU5uPCkd+kC83cLlpgzyOsnpj2S7N+lQgsQb8uY=";

  # The timeout test's fake `go` execs /bin/sleep, absent from the sandbox.
  postPatch = ''
    substituteInPlace version/version_test.go \
      --replace-fail /bin/sleep ${lib.getExe' coreutils "sleep"}
  '';

  ldflags = [
    "-s"
    "-w"
  ];

  nativeBuildInputs = [
    installShellFiles
    writableTmpDirAsHomeHook
  ];

  postInstall = lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
    installShellCompletion --cmd bootdev \
      --bash <(HOME=$(mktemp -d) $out/bin/bootdev completion bash) \
      --zsh <(HOME=$(mktemp -d) $out/bin/bootdev completion zsh) \
      --fish <(HOME=$(mktemp -d) $out/bin/bootdev completion fish)
  '';

  nativeInstallCheckInputs = [versionCheckHook];
  versionCheckProgram = "${placeholder "out"}/bin/bootdev";
  versionCheckProgramArg = "--version";
  doInstallCheck = true;

  meta = {
    description = "CLI used to complete coding challenges and lessons on Boot.dev";
    homepage = "https://github.com/bootdotdev/bootdev";
    changelog = "https://github.com/bootdotdev/bootdev/releases/tag/v${version}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [vinnymeller];
    mainProgram = "bootdev";
  };
}
