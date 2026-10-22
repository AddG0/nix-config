# The files a claude-code profile writes, and the plugin directories Claude Code checks while they build.
{
  harness,
  pkgs,
  ...
}: let
  evalClaude = settings: profile:
    harness.eval [
      (harness.module ../default.nix)
      {
        programs.claude-code-profiles =
          {
            enable = true;
            package = pkgs.claude-code;
            profiles.default = profile;
          }
          // settings;
      }
    ];
  wrapperOf = settings: profile: (evalClaude settings profile).programs.claude-code-profiles.wrapperPackage;

  lspServers.rust = {
    command = "rust-analyzer";
    extensionToLanguage.".rs" = "rust";
  };
  lspManifest = ".config/claude-code/profiles/default/plugins/lsp/.claude-plugin/plugin.json";
  rendered = harness.files (evalClaude {package = harness.stubs.claude;} {inherit lspServers;}).home.file;
  checkedLsp = harness.files (evalClaude {} {inherit lspServers;}).home.file;

  goodPlugin = pkgs.writeTextDir ".claude-plugin/plugin.json" ''{"name": "good", "description": "A plugin Claude Code accepts."}'';
  badPlugin = pkgs.writeTextDir ".claude-plugin/plugin.json" ''{"description": 3}'';
  pluginCheck = import ../plugin-check.nix {
    inherit (harness) lib;
    inherit pkgs;
    cfg = {
      checkConfig = true;
      package = pkgs.claude-code;
    };
  };
  badPluginBuild = pkgs.testers.testBuildFailure (pluginCheck.pluginDir badPlugin);
in
  harness.check "claude-code-files" ''
    ${rendered.jq "the LSP plugin manifest names the plugin" lspManifest ''.name == "lsp"''}
    ${checkedLsp.exists "Claude Code accepts the generated LSP plugin while its manifest builds" lspManifest}
    ${harness.paths.exists "a plugin directory Claude Code accepts builds into the wrapper" "${wrapperOf {} {pluginDirs = [goodPlugin];}}/bin/claude"}
    ${harness.paths.contains "a plugin directory Claude Code rejects fails its checked copy's build, naming the directory" "${badPluginBuild}/testBuildFailure.log" ["claude plugin validate rejected the plugin directory ${badPlugin}"]}
    ${harness.paths.contains "the wrapper loads the checked copy of a plugin directory" "${wrapperOf {} {pluginDirs = [goodPlugin];}}/bin/claude" [''--plugin-dir "${pluginCheck.pluginDir goodPlugin}"'']}
    ${harness.paths.contains "checkConfig off passes a plugin directory to the wrapper unchecked" "${wrapperOf {checkConfig = false;} {pluginDirs = [badPlugin];}}/bin/claude" [''--plugin-dir "${badPlugin}"'']}
  ''
