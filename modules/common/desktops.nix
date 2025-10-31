{lib, ...}: {
  options.desktops = {
    catppuccin = {
      flavor = lib.mkOption {
        type = lib.types.enum ["mocha" "macchiato" "frappe" "latte"];
        default = "mocha";
        description = "The Catppuccin flavor to apply to the desktop theme.";
      };
    };
  };
}
