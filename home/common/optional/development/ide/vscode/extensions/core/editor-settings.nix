_: {
  extensions = [];
  userSettings = {
    # Auto-save
    "files.autoSave" = "afterDelay";
    "files.autoSaveDelay" = 1000;

    # Font settings (JetBrains Mono recommended)
    "editor.fontFamily" = "'JetBrains Mono', 'Fira Code', 'Cascadia Code', monospace";
    "editor.fontSize" = 14;
    "editor.fontLigatures" = true;
    "editor.lineHeight" = 1.5;

    # Cursor
    "editor.cursorBlinking" = "smooth";
    "editor.cursorSmoothCaretAnimation" = "on";
    "editor.cursorStyle" = "line";
    "editor.cursorWidth" = 2;

    # Scrolling
    "editor.smoothScrolling" = true;
    "workbench.list.smoothScrolling" = true;
    "editor.fastScrollSensitivity" = 5;

    # Editor behavior
    "editor.formatOnSave" = true;
    "editor.formatOnPaste" = false;
    "editor.linkedEditing" = true;
    "editor.bracketPairColorization.enabled" = true;
    "editor.guides.bracketPairs" = "active";
    "editor.renderWhitespace" = "selection";
    "editor.wordWrap" = "off";
    "editor.minimap.enabled" = false;
    "editor.stickyScroll.enabled" = true;
    "editor.inlayHints.enabled" = "onUnlessPressed";
    "editor.suggest.preview" = true;
    "editor.acceptSuggestionOnEnter" = "smart";

    # Diff editor
    "diffEditor.ignoreTrimWhitespace" = false;
    "diffEditor.renderSideBySide" = true;
    "diffEditor.wordWrap" = "off";

    # Workbench
    "workbench.startupEditor" = "none";
    "workbench.editor.enablePreview" = false;
    "workbench.tree.indent" = 16;
    "workbench.editor.highlightModifiedTabs" = true;

    # Workspace trust
    "security.workspace.trust.enabled" = true;
    "security.workspace.trust.untrustedFiles" = "prompt";

    # Files
    "files.trimTrailingWhitespace" = true;
    "files.insertFinalNewline" = true;
    "files.trimFinalNewlines" = true;
    "files.associations" = {
      "*.env.*" = "dotenv";
      "flake.lock" = "json";
    };

    # Search
    "search.exclude" = {
      "**/node_modules" = true;
      "**/result" = true;
      "**/.direnv" = true;
      "**/.devenv" = true;
      "**/dist" = true;
      "**/build" = true;
      "**/.git" = true;
    };

    # Explorer
    "explorer.confirmDelete" = false;
    "explorer.confirmDragAndDrop" = false;
    "explorer.compactFolders" = false;

    # Extensions (managed by Nix)
    "extensions.autoUpdate" = false;
    "extensions.autoCheckUpdates" = false;

    # Zen mode
    "zenMode.hideLineNumbers" = false;
    "zenMode.centerLayout" = true;

    # Disable screen reader detection prompt in status bar
    "editor.accessibilitySupport" = "off";
  };
}
