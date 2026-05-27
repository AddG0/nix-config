{
  config,
  lib,
  pkgs,
  ...
}: let
  c = config.lib.stylix.colors.withHashtag;
  yaml = pkgs.formats.yaml {};

  # Minimal bash shell for `mani exec` / `mani run` that pre-loads only the
  # home-manager shell aliases — no plugins, prompt, or completions. About
  # 10x faster than `zsh -ic` (~20ms vs ~210ms per invocation, which matters
  # when fanning out across hundreds of projects).
  aliasLines = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (n: v: "alias ${n}=${lib.escapeShellArg v}") config.home.shellAliases
  );
  mani-shell = pkgs.writeShellScriptBin "mani-shell" ''
    shopt -s expand_aliases
    ${aliasLines}
    eval "''${2:-}"
  '';
in {
  home.packages = [pkgs.mani];

  xdg.configFile."mani/config.yaml".source = yaml.generate "mani-config.yaml" {
    # mani invokes `<shell> -c "<cmd>"`. Wrapper sources aliases and evals
    # the command so `gst`/`gl`/etc. resolve.
    shell = "${mani-shell}/bin/mani-shell";

    themes = {
      shq = {
        stream = {
          prefix = true;
          prefix_colors = [c.base0E c.base0B c.base08 c.base0D c.base0C c.base09];
          header = true;
          header_prefix = "TASK";
          header_char = "*";
        };
        table = {
          style = "rounded";
          border = {
            around = false;
            columns = true;
            header = true;
            rows = false;
          };
          header = {
            fg = c.base0E;
            attr = "bold";
          };
          title_column = {
            fg = c.base0D;
            attr = "bold";
          };
        };
        tree.style = "rounded";
      };
    };

    specs = {
      # Sequential baseline. Safe for tasks that may prompt (push, pull
      # with creds), mutate shared state, or where you want to ctrl-c on
      # the first failure.
      default = {
        output = "stream";
        parallel = false;
        forks = 4;
        ignore_errors = false;
        ignore_non_existing = true;
        omit_empty_rows = true;
        omit_empty_columns = true;
      };
      # Opt-in for read-only ops. Reference with `spec: fast` per task.
      fast = {
        output = "stream";
        parallel = true;
        forks = 8;
        ignore_errors = true;
        ignore_non_existing = true;
        omit_empty_rows = true;
        omit_empty_columns = true;
      };
    };

    tasks = {
      # Read-only tasks default to all projects. Safe to fan out — no
      # prompts, no mutations. Override per-invocation with -k / -d / -p.
      gst = {
        desc = "git status across all projects";
        spec = "fast";
        target = {all = true;};
        cmd = "git status -sb";
      };
      gf = {
        desc = "git fetch --prune across all projects";
        spec = "fast";
        target = {all = true;};
        cmd = "git fetch --prune";
      };
      branch = {
        desc = "current branch name (all projects)";
        spec = "fast";
        target = {all = true;};
        cmd = "git rev-parse --abbrev-ref HEAD";
      };
      # Mutating / auth-prompting tasks stay explicit — no default target,
      # so `mr gl` alone errors out. Force the target with `mr gl -k` etc.
      gl = {
        desc = "git pull --ff-only";
        cmd = "git pull --ff-only";
      };
    };
  };

  home.shellAliases = {
    mr = "mani run";
    me = "mani exec";
    ml = "mani list";
    msy = "mani sync";
  };
}
