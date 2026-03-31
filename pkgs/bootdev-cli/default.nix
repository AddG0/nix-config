{
  lib,
  stdenv,
  buildGoModule,
  fetchFromGitHub,
  installShellFiles,
  versionCheckHook,
  writableTmpDirAsHomeHook,
}:
buildGoModule rec {
  pname = "bootdev-cli";
  version = "1.27.4";

  src = fetchFromGitHub {
    owner = "bootdotdev";
    repo = "bootdev";
    tag = "v${version}";
    hash = "sha256-9avSkYxXqwaLCJeNTJJG8biEVUwZVYRauZclw8wbd50=";
  };

  vendorHash = "sha256-ZDioEU5uPCkd+kC83cLlpgzyOsnpj2S7N+lQgsQb8uY=";

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
      --bash <($out/bin/bootdev completion bash) \
      --zsh <($out/bin/bootdev completion zsh) \
      --fish <($out/bin/bootdev completion fish)
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
