# Which target can route a model string; each target keeps only its own, and default.nix warns on a model none routes.
{lib}: let
  # Claude Code's documented aliases; `inherit` is a subagent's "use the session model".
  claudeAliases = ["default" "best" "inherit" "sonnet" "opus" "haiku" "fable" "opusplan"];
  # Any Claude name may carry a context suffix such as `[1m]`.
  claudeModel = "(${lib.concatStringsSep "|" claudeAliases}|claude-.+)(\\[[^]]*])?";
  openaiModel = "(gpt-|chatgpt-|codex-|o[0-9]).*";
in {
  # "claude-code", "codex", "opencode" for a `provider/model` id, or null for a model no target claims.
  targetForModel = model:
    if model == null
    then null
    else if lib.hasInfix "/" model
    then "opencode"
    else if builtins.match claudeModel model != null
    then "claude-code"
    else if builtins.match openaiModel model != null
    then "codex"
    else null;
}
