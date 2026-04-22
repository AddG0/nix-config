{
  lib,
  pkgs,
  ...
}: let
  logo-theme =
    pkgs.runCommand "plymouth-theme-logo" {
      nativeBuildInputs = [pkgs.librsvg];
    } ''
      themeDir=$out/share/plymouth/themes/logo
      mkdir -p $themeDir

      rsvg-convert -w 400 -h 476 ${./image.svg} -o $themeDir/logo.png

      cat > $themeDir/logo.plymouth <<EOF
      [Plymouth Theme]
      Name=Logo
      Description=Static logo boot screen
      ModuleName=script

      [script]
      ImageDir=$themeDir
      ScriptFile=$themeDir/logo.script
      EOF

      cat > $themeDir/logo.script <<'EOF'
      Window.SetBackgroundTopColor(0, 0, 0);
      Window.SetBackgroundBottomColor(0, 0, 0);

      logo.image = Image("logo.png");
      logo.sprite = Sprite(logo.image);
      logo.sprite.SetX(Window.GetX() + Window.GetWidth() / 2 - logo.image.GetWidth() / 2);
      logo.sprite.SetY(Window.GetY() + Window.GetHeight() / 2 - logo.image.GetHeight() / 2);
      EOF
    '';
in {
  boot.plymouth = {
    theme = lib.mkOverride 49 "logo";
    themePackages = [logo-theme];
  };

  # Load Intel KMS in initrd so plymouth draws directly to i915 from the start.
  # Otherwise plymouth attaches to the EFI simpledrm framebuffer, which i915
  # then takes over a fraction of a second later, leaving plymouth invisible.
  boot.initrd.kernelModules = ["i915"];
}
