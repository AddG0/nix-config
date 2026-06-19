{pkgs, ...}: {
  # JProfiler is a Java/Swing app on a bundled JDK 11, so it renders through
  # XWayland. _JAVA_AWT_WM_NONREPARENTING=1 fixes the gray-box / mislaid-content
  # case under non-reparenting compositors (Hyprland). Note: XWayland still
  # mishandles dynamic window resizes for AWT — an upstream limit only a native
  # Wayland JDK toolkit (e.g. JetBrains Runtime) fixes, which JProfiler can't use.
  home.packages = [
    (pkgs.symlinkJoin {
      name = "jprofiler-wrapped";
      paths = [pkgs.jprofiler];
      nativeBuildInputs = [pkgs.makeWrapper];
      postBuild = ''
        for b in jprofiler jpcontroller; do
          wrapProgram $out/bin/$b --set _JAVA_AWT_WM_NONREPARENTING 1
        done
      '';
    })
  ];
}
