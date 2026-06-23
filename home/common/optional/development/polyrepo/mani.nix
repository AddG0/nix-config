{
  config,
  lib,
  pkgs,
  ...
}: let
  c = config.lib.stylix.colors.withHashtag;
  yaml = pkgs.formats.yaml {};

  # mani (0.32.1) only reads `shell` from a project mani.yaml, not this user
  # config, so commands run under the default `bash -c` without our aliases.
  # Inject them via BASH_ENV on a wrapped mani binary — bash sources it for
  # every non-interactive shell, covering both `mani run` and `mani exec`.
  aliasLines = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (n: v: "alias ${n}=${lib.escapeShellArg v}") config.home.shellAliases
  );
  mani-aliases = pkgs.writeText "mani-aliases.bash" ''
    shopt -s expand_aliases
    ${aliasLines}
  '';
  mani = pkgs.symlinkJoin {
    name = "mani-aliased";
    paths = [pkgs.mani];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = "wrapProgram $out/bin/mani --set BASH_ENV ${mani-aliases}";
  };
in {
  home.packages = [mani];

  xdg.configFile."mani/config.yaml".source = yaml.generate "mani-config.yaml" {
    # `shell` omitted — mani ignores it in the user config (see note above).
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
