{
  lib,
  stdenv,
  fetchzip,
}:
stdenv.mkDerivation rec {
  pname = "marcusolsson-gantt-panel";
  version = "0.8.1";

  src = fetchzip {
    url = "https://github.com/marcusolsson/grafana-gantt-panel/releases/download/v${version}/marcusolsson-gantt-panel-${version}.zip";
    hash = "sha256-tvBsM9zFCbUq8ObwcAcaPfuYUPTMjaR7AlTeuO3rnP4=";
    stripRoot = false;
  };

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall
    cp -R . $out/
    runHook postInstall
  '';

  meta = with lib; {
    description = "A Gantt chart panel for Grafana";
    longDescription = ''
      The Grafana Gantt Panel is a visualization plugin that creates Gantt charts
      to display tasks over time. Features include identifying task bottlenecks,
      grouping recurring tasks, and displaying task metadata as labels.
    '';
    homepage = "https://github.com/marcusolsson/grafana-gantt-panel";
    license = licenses.asl20;
    maintainers = [];
    platforms = platforms.all;
  };
}
