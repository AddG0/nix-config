{
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs.stable; [
    (python312.withPackages (ps:
      with ps; [
        jupyter-core
        jupyter-events
        jupyterlab
        nbconvert
        notebook
        jupyter-client
        jupyter-server
        jupyterlab-widgets
        jupyterlab-pygments
        jupyterlab-lsp
        python-lsp-server
        jupyterlab-git
        jupyterlab-server
        ipywidgets
        qtconsole
        jedi

        plotly # This is needed for plotly to render in jupyterlab https://community.plotly.com/t/plotly-not-rendering-in-jupyterlab-just-leaving-an-empty-space/85588
        nbformat
      ]))
  ];
}
