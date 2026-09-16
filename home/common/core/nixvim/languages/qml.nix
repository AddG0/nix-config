_: {
  plugins.lsp.servers.qmlls = {
    enable = true;
    # -E: read QML_IMPORT_PATH; qmlls otherwise sees only its own Qt prefix.
    cmd = ["qmlls" "-E"];
  };

  plugins.conform-nvim.settings.formatters_by_ft.qml = ["qmlformat"];
}
