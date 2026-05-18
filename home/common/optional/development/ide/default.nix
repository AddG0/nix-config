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
  lib,
  inputs,
  ...
}: let
  inherit (inputs.nix-jetbrains-plugins.lib) pluginsForIde;
  resolvePlugins = ide: ids:
    builtins.attrValues (pluginsForIde pkgs ide ids);
  commonPlugins = ["com.github.catppuccin.jetbrains" "com.intellij.mermaid" "org.mvnsearch.plugins.justPlugin" "com.intellij.plugins.vscodekeymap"];
  bigDataPlugins = [
    "com.intellij.bigdatatools"
    "com.intellij.bigdatatools.core"
    "com.intellij.bigdatatools.binary.files"
    "intellij.bigdatatools.coreUi"
    "intellij.bigdatatools.gcloud"
    "intellij.bigdatatools.azure"
    "intellij.bigdatatools.awsBase"
    "com.intellij.bigdatatools.kafka"
    "com.intellij.bigdatatools.flink"
    "com.intellij.bigdatatools.metastore.core"
    "com.intellij.bigdatatools.rfs"
    "com.intellij.bigdatatools.spark"
  ];
  # Zeppelin requires Python support (com.intellij.modules.python) — only works in IDEs that bundle it
  zeppelinPlugins = [
    "com.intellij.bigdatatools.zeppelin"
    "Pythonid"
  ];

  # Java LTS releases: 8, 11, 17, then every 4 versions (21, 25, 29, ...).
  # Filter to the ones nixpkgs currently exposes and take the 3 newest, so a
  # nixpkgs bump that adds (e.g.) jdk29 promotes it in without code changes.
  ltsCandidates = [8 11 17] ++ map (n: 21 + 4 * n) (lib.range 0 10);
  availableLts = builtins.filter (v: pkgs ? "jdk${toString v}") ltsCandidates;
  latestLts = lib.lists.sublist (builtins.length availableLts - 3) 3 availableLts;
  jdkLinks = lib.listToAttrs (map (v: {
      name = ".jdks/openjdk-${toString v}";
      value.source = "${pkgs."jdk${toString v}"}/lib/openjdk";
    })
    latestLts);

  mkIde = pkg: extraPlugins: {
    package = pkg;
    plugins = resolvePlugins pkg (commonPlugins ++ extraPlugins);
    settings = {
      theme = "com.github.catppuccin.mocha.islands.jetbrains";
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
      terminal.audibleBell = false;
      extra."editor.xml".EditorSettings = ''
        <option name="IS_HORIZONTAL_SCROLLING_ENABLED" value="true" />
      '';
      ignoredFilePatterns = [
        # VCS
        ".git"
        # Nix
        ".direnv"
        ".devenv"
        ".pre-commit-config.yaml"
        # Gradle
        ".gradle"
        ".kotlin"
        "bin"
        "build"
        "gradlew"
        "gradlew.bat"
        # Java LSP (jdtls) project files
        ".classpath"
        ".factorypath"
        ".project"
        ".settings"
        # Python
        "__pycache__"
      ];
    };
  };
in {
  programs.jetbrains.ides = with pkgs.jetbrains; {
    idea = mkIde idea (["nix-idea" "net.ashald.envfile" "org.jetbrains.plugins.go-template"] ++ bigDataPlugins ++ zeppelinPlugins);
    pycharm = mkIde pycharm [];
    datagrip = mkIde datagrip bigDataPlugins;
    webstorm = mkIde webstorm [];
  };

  programs.git.ignores = lib.custom.gitignoreFromTemplates pkgs.github-gitignore-templates ["Global/JetBrains"];

  # JetBrains IDEs scan ~/.jdks/ for JDKs. Generic-Linux JDKs (e.g. Microsoft,
  # Temurin downloads) fail with "Could not start dynamically linked executable"
  # on NixOS, so expose nixpkgs-patched JDKs here for IntelliJ to discover.
  home.file = lib.mkIf pkgs.stdenv.isLinux jdkLinks;

  home.packages = with pkgs; (
    if pkgs.stdenv.isLinux
    then [
      android-studio
    ]
    else []
  );
}
