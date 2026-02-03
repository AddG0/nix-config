{
  pkgs,
  lib,
  config,
  ...
}: {
  fonts = lib.mkIf (config.hostSpec.hostType != "server") {
    packages = with pkgs;
      [
        # icon fonts
        material-design-icons
        font-awesome
        # The Source Han font series is led by Adobe. The Chinese characters are called "Source Han Sans" and "Source Han Serif", developed jointly by Adobe and Google.
        source-sans # Sans-serif font, does not contain Chinese characters. The font family is called Source Sans 3 and Source Sans Pro, with weight variants, including Source Sans 3 VF.
        source-serif # Serif font, does not contain Chinese characters. The font family is called Source Code Pro, with weight variants.
        source-han-sans # Source Han Sans
        source-han-serif # Source Han Serif
        # nerdfonts (individual packages)
        julia-mono
        dejavu_fonts
        nerd-fonts.jetbrains-mono # JetBrains Mono - used in VS Code terminal
      ]
      ++ (
        if pkgs.stdenv.isDarwin
        then [
          nerd-fonts.fira-code
          nerd-fonts.iosevka
        ]
        else []
      );
  };
}
