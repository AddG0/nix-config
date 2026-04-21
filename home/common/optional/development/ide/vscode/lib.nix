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
  defaultProfileExtensions = with ext;
    [
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
      html
      docker
      shellcheck
      python
      go
      rust
      typescript
      vue
      java
      kotlin
      dotenv
      rainbowCsv
      tailwind
      stylelint
      jupyter
      logHighlighter
      caddyfile
      neo4j
      tilt
      minecraft

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
      leetcode

      # AI
      claudeCode
      supermaven
      copilot
      # continue

      # Keybindings
      # vim
    ]
    ++ (lib.optionals pkgs.stdenv.isLinux) [
      # Productivity
      # Postman uses hashes in the paths so I can't declaritively control the config so settings file keeps saying can't save
      # I prefer to disable it to avoid
      postman
    ];

  defaultProfile = mkProfile defaultProfileExtensions;

  # Strip lib.mkForce/mkOverride wrappers that only the NixOS module
  # system knows how to resolve. jsonFormat.generate serialises them as
  # literal {_type, content, priority} objects, breaking VS Code settings.
  stripOverrides = val:
    if builtins.isAttrs val && val ? _type && val._type == "override"
    then stripOverrides val.content
    else if builtins.isAttrs val
    then builtins.mapAttrs (_: stripOverrides) val
    else if builtins.isList val
    then map stripOverrides val
    else val;

  # Generate settings.json with VSCode-compatible key ordering.
  # Nix attrsets are always alphabetically sorted, but VSCode expects
  # chat.instructionsFilesLocations in a specific order and marks the
  # read-only settings file as dirty when the order doesn't match.
  mkSettingsJson = name: settings:
    pkgs.runCommand name {
      nativeBuildInputs = [pkgs.jq];
      json = builtins.toJSON (stripOverrides settings);
      passAsFile = ["json"];
    } ''
      jq '
        .["chat.instructionsFilesLocations"] |= (
          to_entries
          | sort_by(
              if .key | startswith(".github/") then 0
              elif .key | startswith(".claude/") then 1
              elif .key | startswith("~/.copilot/") then 2
              elif .key | startswith("~/.claude/") then 3
              else 4
              end
            )
          | from_entries
        )
      ' "$jsonPath" > "$out"
    '';
in {
  inherit ext mkProfile profileAttrs extraAttrs defaultProfile defaultProfileExtensions stripOverrides mkSettingsJson;
}
