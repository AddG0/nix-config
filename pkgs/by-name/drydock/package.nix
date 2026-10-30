{
  lib,
  rustPlatform,
  fetchFromGitHub,
  makeWrapper,
  git,
  writableTmpDirAsHomeHook,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "drydock";
  version = "1.3.0";

  src = fetchFromGitHub {
    owner = "yetidevworks";
    repo = "drydock";
    rev = "v${finalAttrs.version}";
    hash = "sha256-7mYpLUqKSO2AtN9FN4vGg5N8hsqGESYsA2YK7YNPWII=";
  };

  cargoHash = "sha256-CfAa0vDVqWP768+mQDITIJuWj+TiaXaT4w4vk7kJkWw=";

  nativeBuildInputs = [makeWrapper];

  # Tests build throwaway repos with `git init` and read config from $HOME.
  nativeCheckInputs = [git writableTmpDirAsHomeHook];

  # inotify events never arrive inside the build sandbox.
  checkFlags = ["--skip=watch::tests::a_real_edit_reaches_the_callback"];

  # Shells out to git rather than linking libgit2.
  postInstall = ''
    wrapProgram $out/bin/drydock --suffix PATH : ${lib.makeBinPath [git]}
  '';

  meta = {
    description = "Live TUI dashboard of uncommitted, unpushed and unreleased work across many git repos";
    homepage = "https://github.com/yetidevworks/drydock";
    license = lib.licenses.mit;
    mainProgram = "drydock";
  };
})
