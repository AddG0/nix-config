# opencode's own validators: `debug config` on the config dir, then its server's skill loading.
{
  config,
  lib,
  pkgs,
}: let
  opencode = config.programs.opencode;
  opencodeDir = "${lib.removePrefix "/" (lib.removePrefix config.home.homeDirectory config.xdg.configHome)}/opencode";
in {
  option = "programs.opencode";
  inherit (opencode) enable package;
  configDirs = [opencodeDir];

  setup = ''
    export OPENCODE_DISABLE_AUTOUPDATE=1
    export OPENCODE_DISABLE_MODELS_FETCH=1
    export OPENCODE_DISABLE_DEFAULT_PLUGINS=1
    export OPENCODE_DISABLE_LSP_DOWNLOAD=1
    export OPENCODE_DISABLE_CLAUDE_CODE=1
    export OPENCODE_DISABLE_SHARE=1
    # opencode retries its plugin-dependency npm install for ~70 s without network.
    export npm_config_fetch_retries=0
  '';

  script = package: ''
    before=$failed
    validate opencode ${lib.escapeShellArg opencodeDir} ${package}/bin/opencode debug config
    # Skill loading reads the same config first, so it would only repeat a config error.
    if [[ $failed -eq $before ]]; then
      validate opencode ${lib.escapeShellArg "${opencodeDir}/skills"} ${lib.getExe (import ./skill-check.nix {inherit pkgs;})} ${package}/bin/opencode "$XDG_CONFIG_HOME/opencode/skills"
    fi
  '';
}
