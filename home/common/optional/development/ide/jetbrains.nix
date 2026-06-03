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
  lib,
  ...
}: let
  inherit (inputs.nix-jetbrains-plugins.lib) pluginsForIde;
  resolvePlugins = ide: ids:
    builtins.attrValues (pluginsForIde pkgs ide ids);
  commonPlugins = [
    "com.github.catppuccin.jetbrains"
    "com.intellij.mermaid"
    "org.mvnsearch.plugins.justPlugin"
    "com.intellij.plugins.vscodekeymap"
    "me.x150.intellij-code-screenshots"
    # Official Anthropic Claude Code plugin (still tagged [Beta]). Runs the
    # Claude Code CLI inside the IDE terminal and surfaces proposed diffs
    # in the IDE's diff viewer. Requires the `claude` CLI to be installed
    # separately — already on PATH via the rest of this config.
    #   https://plugins.jetbrains.com/plugin/27310-claude-code-beta-
    "com.anthropic.code.plugin"
    # GitLab Duo — CI/CD pipeline integration plus AI code suggestions and chat.
    #   https://plugins.jetbrains.com/plugin/22325-gitlab-duo
    "com.gitlab.plugin"
  ];
  # The aggregator meta-plugin `com.intellij.bigdatatools` is intentionally
  # absent: it declares a hard dep on `bigdatatools.zeppelin`, and zeppelin
  # only loads in PyCharm (see zeppelinPlugins below). Including the meta on
  # IDEA/DataGrip would fail plugin verification with
  # "Big Data Tools requires plugin com.intellij.bigdatatools.zeppelin to
  # be enabled". The sub-plugins below provide the actual features.
  bigDataPlugins = [
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
  # Zeppelin notebooks. The sub-plugin requires `intellij.python.community.
  # execService`, a module provided only by the bundled `PythonCore` plugin
  # (Python Community Edition). PyCharm ships PythonCore out of the box;
  # IDEA 2026 ships no Python plugin at all, so zeppelin is PyCharm-only
  # here. `Pythonid` is omitted on purpose — PyCharm bundles it too, and
  # pinning it externally over the bundled copy fails with "requires
  # com.intellij.modules.python".
  zeppelinPlugins = ["com.intellij.bigdatatools.zeppelin"];

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
      # Easy Code Screenshots (me.x150.intellij-code-screenshots). backgroundColor
      # is an ARGB signed-int; -15198171 is catppuccin mocha mantle (#181825).
      extra."codeScreenshots.xml".CodeScreenshotsOptions = ''
        <option name="scale" value="2.0" />
        <option name="removeIndentation" value="true" />
        <option name="innerPadding" value="24.0" />
        <option name="outerPaddingHoriz" value="24.0" />
        <option name="outerPaddingVert" value="24.0" />
        <option name="windowRoundness" value="12" />
        <option name="showWindowControls" value="true" />
        <option name="showFileName" value="true" />
        <option name="backgroundColor" value="-15198171" />
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
    idea = mkIde idea (["nix-idea" "net.ashald.envfile" "org.jetbrains.plugins.go-template"] ++ bigDataPlugins);
    # PyCharm gets the big-data stack too so Zeppelin can sit alongside its
    # dependencies (Spark, Metastore, etc.) — without those the notebook
    # plugin is functional but stranded.
    pycharm = mkIde pycharm (bigDataPlugins ++ zeppelinPlugins);
    datagrip = mkIde datagrip bigDataPlugins;
    webstorm = mkIde webstorm [];
  };

  programs.git.ignores = lib.custom.gitignoreFromTemplates inputs.github-gitignore-templates ["Global/JetBrains"];

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
