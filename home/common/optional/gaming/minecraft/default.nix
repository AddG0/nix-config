_: {
  programs.prismlauncher = {
    enable = true;
    modpacks = {
      "main-1.21.11" = {
        source = ./modpacks/main-1.21.11;
        # Versions auto-detected from pack.toml
        icon = ../../../../../assets/avatars/addg-halloween.png;
      };
    };
  };
}
