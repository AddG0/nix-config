{
  lib,
  pkgs,
  ...
}: let
  # Auto-discover all extension configs from ./extensions/**/*.nix
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

  # Import all .nix files from a category directory (passing pkgs to each)
  importCategory = category: let
    categoryPath = extensionsDir + "/${category}";
    files = builtins.readDir categoryPath;
    nixFiles = lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".nix" name) files;
  in
    lib.mapAttrs' (name: _: {
      name = toCamelCase (lib.removeSuffix ".nix" name);
      value = import (categoryPath + "/${name}") {inherit pkgs;};
    })
    nixFiles;

  # Merge all categories into one attribute set
  ext = lib.foldl (acc: cat: acc // (importCategory cat)) {} categories;

  # Helper to build a profile from a list of extension configs
  # Merges: extensions, userSettings, keybindings, globalSnippets,
  # languageSnippets, userMcp, userTasks
  mkProfile = exts: {
    extensions = lib.flatten (map (e: e.extensions or []) exts);
    userSettings = lib.foldl (acc: e: acc // (e.userSettings or {})) {} exts;
    keybindings = lib.flatten (map (e: e.keybindings or []) exts);
    globalSnippets = lib.foldl (acc: e: acc // (e.globalSnippets or {})) {} exts;
    languageSnippets = lib.foldl (acc: e: acc // (e.languageSnippets or {})) {} exts;
    userMcp = lib.foldl (acc: e: acc // (e.userMcp or {})) {} exts;
    userTasks = lib.foldl (acc: e: acc // (e.userTasks or {})) {} exts;
  };
in {
  programs.vscode = {
    enable = true;
    profiles = {
      default = mkProfile (with ext; [
        # Core
        editorSettings
        terminal
        remoteSsh
        materialIcons

        # UI / Theme
        catppuccin
        betterComments
        indentRainbow
        colorHighlight
        svgPreview
        peacock
        outputColorizer

        # Git
        gitlens
        gitGraph
        gitlab
        githubPr
        githubActions

        # Languages
        nixIde
        yaml
        toml
        json
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
        dotenv
        rainbowCsv
        tailwind
        stylelint
        jupyter
        logHighlighter

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
        drawio
        liveshare
        regexPreviewer
        codeRunner
        hexEditor
        excalidraw
        codesnap
        partialDiff

        # AI
        chat
        supermaven
        # copilot
        # continue

        # Keybindings
        # vim
      ]);
    };
  };
}
