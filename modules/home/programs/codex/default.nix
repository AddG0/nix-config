{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.codex.mutableConfig;
  codex = config.programs.codex;

  mergeProgram = import ./merge-program.nix {inherit pkgs;};

  # Upstream writes config.toml only when it has settings to put in it.
  managed = codex.settings != null && codex.settings != {};

  # Upstream strips the home prefix without its slash, hence the leading one. A
  # key that stops matching upstream's fails on the source read below.
  configKey =
    if config.home.preferXdgDirectories
    then "${lib.removePrefix config.home.homeDirectory config.xdg.configHome}/codex/config.toml"
    else ".codex/config.toml";

  targetPath =
    if config.home.preferXdgDirectories
    then "${config.xdg.configHome}/codex/config.toml"
    else "${config.home.homeDirectory}/.codex/config.toml";
in {
  options.programs.codex.mutableConfig = {
    enable =
      lib.mkEnableOption ""
      // {
        description = ''
          Replace the store link at `CODEX_HOME/config.toml` with a writable
          copy after activation, merging back whatever Codex wrote into it.

          Codex persists project trust into that file, so a read-only link
          makes accepting the trust prompt fail and the prompt returns every
          launch. There is no global trust setting to declare instead, and
          `--dangerously-bypass-approvals-and-sandbox` does not skip the
          screen: <https://github.com/openai/codex/issues/14547>.

          Declared settings still win; anything Codex added that Nix does not
          manage survives the rebuild.
        '';
      };

    program = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      default = mergeProgram;
      defaultText = lib.literalMD "the bundled merge helper";
      description = "Helper that merges the runtime config.toml over the declared one.";
    };
  };

  config = lib.mkIf (codex.enable && cfg.enable && managed) {
    # Unmanaged on purpose: `force` only skips the collision check — linkGeneration
    # still moves a real file to <name>.backup each switch, and the next switch
    # aborts on it. Cleanup skips non-symlinks, so what we write below stays.
    home.file.${configKey}.enable = false;

    home.activation.codexMutableConfig = lib.hm.dag.entryAfter ["linkGeneration"] ''
      run ${lib.getExe cfg.program} \
        ${config.home.file.${configKey}.source} \
        ${lib.escapeShellArg targetPath}
    '';
  };
}
