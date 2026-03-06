# Adding a custom JDBC driver (e.g. Apache Pinot, ClickHouse):
#   1. Database tool window → + → Data Source → Other
#   2. Driver tab → + → set Name, add the JAR (or paste Maven coords
#      like org.apache.pinot:pinot-jdbc-client:1.4.0 and let IntelliJ fetch it)
#   3. Set Driver class, JDBC URL, and test the connection
#
# Direct JAR downloads live on Maven Central:
#   https://repo1.maven.org/maven2/org/apache/pinot/pinot-jdbc-client/
{
  pkgs,
  inputs,
  ...
}: let
  inherit (inputs.nix-jetbrains-plugins.lib) pluginsForIde;
  resolvePlugins = ide: ids:
    builtins.attrValues (pluginsForIde pkgs ide ids);
  commonPlugins = ["com.github.catppuccin.jetbrains" "com.intellij.mermaid" "org.mvnsearch.plugins.justPlugin" "com.intellij.plugins.vscodekeymap"];

  mkIde = pkg: extraPlugins: {
    package = pkg;
    plugins = resolvePlugins pkg (commonPlugins ++ extraPlugins);
    settings = {
      theme = "com.github.catppuccin.mocha.jetbrains";
      colorScheme = "Catppuccin Mocha";
      keymap = {
        name = "VSCode Custom";
        parent = "VSCode";
        actions = {
          EditorEscape = [];
          "Terminal.CopySelectedText" = ["ctrl shift C"];
          "Terminal.Paste" = ["ctrl shift V"];
        };
      };
      ignoredFilePatterns = [".direnv" ".git" ".gradle" ".kotlin" ".pre-commit-config.yaml" "bin" "build" "gradlew" "gradlew.bat"];
    };
  };
in {
  programs.jetbrains.ides = with pkgs.jetbrains; {
    idea = mkIde idea ["nix-idea" "net.ashald.envfile" "org.jetbrains.plugins.go-template"];
    pycharm = mkIde pycharm [];
    datagrip = mkIde datagrip [];
    webstorm = mkIde webstorm [];
  };

  home.packages = with pkgs;
    [
      # jetbrains.phpstorm
      # vscode
      code-cursor
    ]
    ++ (
      if pkgs.stdenv.isLinux
      then [
        android-studio
      ]
      else []
    );
}
