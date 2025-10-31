{pkgs, ...}: let
  create-jupyter-kernel = pkgs.writeShellApplication {
    name = "jupyter-create-kernel";
    text = ''
      arg="''${1:-}"
      if [ -z "$arg" ]; then
        echo "Please specify a name for the kernel"
        exit 1
      fi

      python -m ipykernel install --user --name="$arg" --display-name "Python ($arg)"
    '';
  };
in {
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
    create-jupyter-kernel
  ];
}
