# opencode's own validators: `debug config` on the config dir, then `debug skill`.
{
  config,
  lib,
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
    # `debug skill` loads the same config first, so it would only repeat a config error.
    if [[ $failed -eq $before ]]; then
      validate opencode ${lib.escapeShellArg "${opencodeDir}/skills"} ${package}/bin/opencode debug skill
    fi
  '';
}
