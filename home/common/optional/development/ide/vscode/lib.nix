# Shared VSCode extension configuration library
# Used by both local vscode (default.nix) and vscode-server (server.nix)
{
  lib,
  pkgs,
  config,
  hostSpec,
}: let
  extensionsDir = ./extensions;

  # Convert kebab-case to camelCase (e.g., "nix-ide" -> "nixIde")
  toCamelCase = str: let
    parts = lib.splitString "-" str;
    first = builtins.head parts;
    rest = builtins.tail parts;
    capitalize = s: lib.toUpper (lib.substring 0 1 s) + lib.substring 1 (-1) s;
  in
    first + lib.concatStrings (map capitalize rest);

  # Get all category directories
  categories = builtins.attrNames (builtins.readDir extensionsDir);

  # Import all .nix files from a category directory
  importCategory = category: let
    categoryPath = extensionsDir + "/${category}";
    files = builtins.readDir categoryPath;
    nixFiles = lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".nix" name) files;
  in
    lib.mapAttrs' (name: _: {
      name = toCamelCase (lib.removeSuffix ".nix" name);
      value = import (categoryPath + "/${name}") {inherit pkgs config lib hostSpec;};
    })
    nixFiles;

  # All extensions merged into one attribute set
  ext = lib.foldl (acc: cat: acc // (importCategory cat)) {} categories;

  # Known VS Code profile attributes with special merge logic
  profileAttrs = ["extensions" "userSettings" "keybindings" "globalSnippets" "languageSnippets" "userMcp" "userTasks"];

  # Helper to build a profile from a list of extension configs
  mkProfile = exts: {
    extensions = lib.flatten (map (e: e.extensions or []) exts);
    userSettings = lib.foldl (acc: e: lib.recursiveUpdate acc (e.userSettings or {})) {} exts;
    keybindings = lib.flatten (map (e: e.keybindings or []) exts);
    globalSnippets = lib.foldl (acc: e: acc // (e.globalSnippets or {})) {} exts;
    languageSnippets = lib.foldl (acc: e: acc // (e.languageSnippets or {})) {} exts;
    userMcp = lib.foldl (acc: e: acc // (e.userMcp or {})) {} exts;
    userTasks = lib.foldl (acc: e: acc // (e.userTasks or {})) {} exts;
  };

  # Collect all non-profile attributes from extensions and merge them (for home.file, etc.)
  extraAttrs =
    lib.foldl
    (acc: e: lib.recursiveUpdate acc (removeAttrs e profileAttrs))
    {}
    (builtins.attrValues ext);

  # Default profile with all standard extensions
  defaultProfileExtensions = with ext; [
    # Core
    editorSettings
    terminal
    remoteSsh
    materialIcons
    direnv
    indentOnEmptyLine

    # UI / Theme
    catppuccin
    betterComments
    indentRainbow
    colorHighlight
    svgPreview
    peacock
    outputColorizer

    # Git
    git
    gitlens
    gitGraph
    gitlab
    githubPr
    githubActions

    # Languages
    nixIde
    yaml
    toml
    # json
    justfile
    protobuf
    xml
    markdown
    mermaid
    docker
    shellcheck
    python
    go
    rust
    typescript
    java
    kotlin
    dotenv
    rainbowCsv
    tailwind
    stylelint
    jupyter
    logHighlighter
    neo4j
    tilt

    # Infrastructure
    kubernetes
    terraform
    helm
    terramate

    # Productivity
    projectManager
    errorlens
    todoTree
    spellChecker
    editorconfig
    postman
    pathIntellisense
    autoRenameTag
    liveServer
    sqltools
    importCost
    bookmarks
    # drawio
    liveshare
    regexPreviewer
    codeRunner
    hexEditor
    # excalidraw
    codesnap
    partialDiff

    # AI
    claudeCode
    supermaven
    copilot
    # continue

    # Keybindings
    # vim
  ];

  defaultProfile = mkProfile defaultProfileExtensions;
in {
  inherit ext mkProfile profileAttrs extraAttrs defaultProfile defaultProfileExtensions;
}
