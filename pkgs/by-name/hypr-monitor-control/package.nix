# `hypr-monitor-control`: the command that lists, disables, enables, toggles, re-rates and recovers Hyprland monitors at runtime.
{
  lib,
  callPackage,
  runCommandLocal,
  symlinkJoin,
  writeShellApplication,
  coreutils,
  gnugrep,
  hyprland,
  jq,
  # The declared layout `hypr-monitor-control recover` restores; null makes recover refuse.
  # { primaryMonitor = "eDP-1"; workspaceMonitors = [{ workspace = "1"; monitor = "DP-3"; }]; }
  layout ? null,
}: let
  bin = writeShellApplication {
    name = "hypr-monitor-control";
    runtimeInputs = [hyprland jq coreutils gnugrep];
    text =
      ''
        declared_layout=${
          if layout == null
          then "0"
          else "1"
        }
        primary_monitor=${lib.escapeShellArg (layout.primaryMonitor or "")}
        workspace_monitors=(${lib.escapeShellArgs (map (w: "${w.workspace}:${w.monitor}") (layout.workspaceMonitors or []))})
      ''
      + builtins.readFile ./hypr-monitor-control.sh;
  };

  completions = runCommandLocal "hypr-monitor-control-completions" {} ''
    install -Dm644 ${./completions/_hypr-monitor-control} $out/share/zsh/site-functions/_hypr-monitor-control
    install -Dm644 ${./completions/hypr-monitor-control.bash} $out/share/bash-completion/completions/hypr-monitor-control
  '';
in
  symlinkJoin {
    name = "hypr-monitor-control";
    paths = [bin completions];

    passthru = {
      nixUpdate.version = "skip";
      tests.script = callPackage ./tests/script.nix {};
    };

    meta = {
      description = "Runtime Hyprland monitor control: list, disable, enable, toggle, rate, recover";
      mainProgram = "hypr-monitor-control";
      platforms = lib.platforms.linux;
    };
  }
