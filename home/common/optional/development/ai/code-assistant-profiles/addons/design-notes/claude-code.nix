# Engineering documentation conventions — Claude Code wiring.
{pkgs, ...}: let
  sessionStartHook = pkgs.writeShellApplication {
    name = "design-notes-session-start";
    # GNU find for -printf, coreutils for paste/wc.
    runtimeInputs = with pkgs; [jq coreutils gnugrep gnused findutils];
    text = builtins.readFile ./hooks/session-start.sh;
  };
in {
  programs.claude-code-profiles.addons.design-notes = {
    settings.permissions.allow = ["Edit(docs/adr/**)" "Edit(docs/steering/**)" "Edit(docs/work/**)"];

    # Second entry re-runs it after compaction, which drops the first summary.
    settings.hooks.SessionStart = [
      {
        hooks = [
          {
            type = "command";
            command = "${sessionStartHook}/bin/design-notes-session-start";
          }
        ];
      }
      {
        matcher = "compact";
        hooks = [
          {
            type = "command";
            command = "${sessionStartHook}/bin/design-notes-session-start";
          }
        ];
      }
    ];
  };
}
