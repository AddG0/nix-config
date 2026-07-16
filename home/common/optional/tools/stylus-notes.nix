{pkgs, ...}: {
  # Stylus/drawing-tablet note apps: rnote (infinite canvas), xournalpp (PDF + LaTeX).
  home.packages = with pkgs; [rnote xournalpp];
}
