{lib, ...}: {
  options.desktops = {
    appearance = lib.mkOption {
      type = lib.types.enum ["default" "linux-esque"];
      default = "default";
      description = "The overall appearance style for the desktop environment.";
    };

    linux-esque = {
      bar = lib.mkOption {
        type = lib.types.enum ["sketchybar" "other"];
        default = "sketchybar";
        description = "The bar system to use in the Linux-inspired setup.";
      };

      borders = lib.mkOption {
        type = lib.types.enum ["janky" "none"];
        default = "janky";
        description = "The window border style.";
      };
    };
  };
}
