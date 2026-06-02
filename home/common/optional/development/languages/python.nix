{
  pkgs,
  inputs,
  lib,
  ...
}: {
  programs.git.ignores =
    lib.filter
    (entry: !(builtins.elem entry ["lib/" "lib64/"]))
    (lib.custom.gitignoreFromTemplates inputs.github-gitignore-templates ["Python"]);

  home.packages = with pkgs; [
    (lib.lowPrio python3) # jupyter env wins python3.pc collision
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
