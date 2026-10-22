# `claude plugin validate` run while a plugin directory builds, so a profile never loads one Claude Code rejects.
{
  cfg,
  lib,
  pkgs,
}: let
  enabled = cfg.checkConfig;

  claude = dir: lib.throwIf (cfg.package == null) "programs.claude-code-profiles.checkConfig is on but programs.claude-code-profiles.package is null, so `claude plugin validate` cannot check ${toString dir}; set package, or checkConfig = false to load plugin directories unchecked" (lib.getExe' cfg.package "claude");

  validate = dir:
    lib.optionalString enabled ''
      HOME=$TMPDIR DISABLE_AUTOUPDATER=1 CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 ${claude dir} plugin validate ${dir} >&2 </dev/null || {
        echo "claude plugin validate rejected the plugin directory ${dir}" >&2
        exit 1
      }
    '';
in {
  inherit validate;

  # Only a store path is there to read while building; one outside the store loads unchecked.
  pluginDir = dir:
    if enabled && lib.hasPrefix "${builtins.storeDir}/" (toString dir)
    then
      pkgs.runCommand "claude-plugin-${lib.strings.sanitizeDerivationName (baseNameOf (toString dir))}" {} ''
        ${validate dir}
        ln -s ${dir} "$out"
      ''
    else dir;
}
