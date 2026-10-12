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
  version = "1.2.2";

  src = fetchFromGitHub {
    owner = "yetidevworks";
    repo = "drydock";
    rev = "v${finalAttrs.version}";
    hash = "sha256-58gJrQUV48WRxFxsS9gUAqbjHyDHEoUMo6Srk+zO31w=";
  };

  cargoHash = "sha256-a7GEKlTZ/r3aeOw7fetyfMYeFPO0riDt945HdmVNvJU=";

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
