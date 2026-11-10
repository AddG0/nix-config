# Claude Code hooks that hold code to the code-standards rules whatever survived in context; Codex's aren't ported (ADR 0024).
{pkgs, ...}: let
  commentBlockHook = pkgs.writeShellApplication {
    name = "comment-block";
    runtimeInputs = [pkgs.jq pkgs.gawk];
    text = builtins.readFile ./hooks/comment-block.sh;
  };
  selfDocumenting = import ./self-documenting-gate/hooks.nix {inherit pkgs;};
  command = drv: [
    {
      type = "command";
      command = "${drv}/bin/${drv.name}";
    }
  ];
in {
  programs.claude-code-profiles.addons.code-standards.settings.hooks = {
    # Edit only: a new file's header is the noisiest false positive and the
    # rarest real offender.
    PostToolUse = [
      {
        matcher = "Edit";
        hooks = command commentBlockHook;
      }
    ];
    SessionStart = [{hooks = command selfDocumenting.baseline;}];
    Stop = [{hooks = command selfDocumenting.gate;}];
  };
}
