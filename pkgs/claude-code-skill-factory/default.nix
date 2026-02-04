{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation {
  pname = "claude-code-skill-factory";
  version = "unstable-2025-02-04";

  src = fetchFromGitHub {
    owner = "alirezarezvani";
    repo = "claude-code-skill-factory";
    rev = "ba18b31703542d9d7eda5f9ba94f0df65a59dddf";
    sha256 = "0rkn0ac5zs1ys5b6bwj1cnj42nx3j6mnh4a449idggb0yxln44zk";
  };

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/claude-code/plugins/claude-code-skill-factory
    cp -r . $out/share/claude-code/plugins/claude-code-skill-factory/
    runHook postInstall
  '';

  meta = with lib; {
    description = "Toolkit for building Claude Skills, Agents, Commands, and Hooks with interactive builders";
    homepage = "https://github.com/alirezarezvani/claude-code-skill-factory";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
