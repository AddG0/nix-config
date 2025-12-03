{pkgs, ...}: {
  home.packages = with pkgs; [
    docker-compose
    dive # explore docker layers
    lazydocker # Docker terminal UI.
    skopeo # copy/sync images between registries and local storage
    go-containerregistry # provides `crane` & `gcrane`, it's similar to skopeo
    ko # build go project to container image
  ];

  programs.zsh.oh-my-zsh.plugins = [
    "docker-compose"
    "docker"
  ];
}
