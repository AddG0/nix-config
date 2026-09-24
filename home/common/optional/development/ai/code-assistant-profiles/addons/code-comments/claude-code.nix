# The comments rule loads every session and still gets broken, so this is the
# structural half: a hook fires regardless of what survived in context.
# Claude Code only — code-assistant-profiles is tool-agnostic and has no hooks.
{pkgs, ...}: let
  commentBlockHook = pkgs.writeShellApplication {
    name = "comment-block";
    runtimeInputs = [pkgs.jq pkgs.gawk];
    text = builtins.readFile ./hooks/comment-block.sh;
  };
in {
  programs.claude-code-profiles.addons.code-comments = {
    # Edit only: a new file's header is the noisiest false positive and the
    # rarest real offender.
    settings.hooks.PostToolUse = [
      {
        matcher = "Edit";
        hooks = [
          {
            type = "command";
            command = "${commentBlockHook}/bin/comment-block";
          }
        ];
      }
    ];
  };
}
