# The schema of one target's validator: which home files are its tool's, and the shell that runs the tool's own checks over them.
{lib}:
lib.types.submodule {
  options = {
    option = lib.mkOption {
      type = lib.types.str;
      example = "programs.codex";
      description = "The tool's home-manager option, named in errors; its `package` is `<option>.package`.";
    };

    enable = lib.mkOption {
      type = lib.types.bool;
      description = "Whether this home writes the tool's config, so its validator runs.";
    };

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      description = "The tool the host installs; a null one fails the check rather than skipping the validator.";
    };

    configDirs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "Dirs relative to $HOME holding the tool's config; an enabled tool with no home file under them fails evaluation.";
    };

    extraDirs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Further dirs relative to $HOME whose files the tool reads, linked into the fake $HOME too.";
    };

    mergedFiles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Files relative to $HOME that activation merges, so their home.file entries are disabled; the check links their declared source anyway.";
    };

    setup = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Shell run once before any user's validators: exports and helper functions.";
    };

    script = lib.mkOption {
      type = lib.types.functionTo lib.types.lines;
      description = ''
        Called with `package`, the shell that validates one user's fake $HOME.
        It runs only for an enabled tool, with `$HOME` and `$XDG_CONFIG_HOME`
        set, and reports through `validate <tool> <file> <command...>` or
        `report <tool> <file> <command> <output>`; `$subject`, `$limit`,
        `$failed`, `$ran` and `plain` are in scope too.
      '';
    };
  };
}
