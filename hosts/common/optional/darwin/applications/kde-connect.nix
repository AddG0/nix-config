{pkgs, ...}: {
  homebrew = {
    taps = [
      "imshuhao/kdeconnect" # KDE Connect nightly builds for macOS
    ];
    casks = [
      "imshuhao/kdeconnect/kdeconnect"
    ];
  };

  environment.systemPackages = [
    (pkgs.writeShellScriptBin "kdeconnect-cli" ''
      exec "/Applications/KDE Connect.app/Contents/MacOS/kdeconnect-cli" "$@"
    '')
  ];
}
