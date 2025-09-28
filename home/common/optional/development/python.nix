{pkgs, ...}: {
  home.packages = with pkgs; [
    python3
    python3Packages.pip
    python3Packages.virtualenv
    poetry
    uv
  ];

  programs.zsh.oh-my-zsh.plugins = [
    "pip"
    "pipenv"
    "pyenv"
    "python"
    "pylint"
  ];

  home.sessionVariables = {
    PYTHON_HOME = "${pkgs.python3}";
  };
}
