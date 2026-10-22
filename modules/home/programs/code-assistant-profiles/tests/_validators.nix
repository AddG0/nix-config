# The tools' own validators as a home's build runs them (its home.checks), over a home built from the flake's home module, for the files: tests.
{
  lib,
  pkgs,
  self,
}: let
  # A home with every tool's validator enabled; the tool modules come through the flake's home module, not an import here.
  evalHome = case: module:
    (self.inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        self.homeModules.default
        # homeModules.default expects these from the host.
        self.inputs.sops-nix.homeManagerModules.sops
        {hostSpec.hostPlatform = pkgs.stdenv.hostPlatform.system;}
        {
          home = {
            username = "fixture-${case}";
            homeDirectory = "/home/t";
            stateVersion = "25.05";
            preferXdgDirectories = true;
          };
          programs.code-assistant-profiles = {
            enable = true;
            targets = {
              claude-code.enable = true;
              codex.enable = true;
              opencode.enable = true;
            };
            profiles.default = {
              instructions.text = "Answer briefly.";
              skills.greet = {
                description = "Greets the user";
                prompt.text = "Say hello.";
              };
              agents.reviewer = {
                description = "Reviews a diff";
                prompt.text = "Review the diff.";
                color = "red";
              };
              lspServers.nil = {
                command = "nil";
                extensionToLanguage.".nix" = "nix";
              };
            };
            profiles.alt = {
              extends = "default";
              mcpServers.demo.command = "/bin/demo";
            };
          };
          programs.claude-code-profiles.profiles.default.settings.permissions.defaultMode = "plan";
        }
        module
      ];
    })
    .config;

  validatorRun = case: module: let
    checks = (evalHome case module).home.checks;
  in
    lib.throwIfNot (lib.length checks == 1) "fixture-${case}: expected the validator run as the home's one check, got ${toString (lib.length checks)}" (lib.head checks);

  # Shell asserting that the validators reject a fixture once, with each `expected` line in their report.
  validatorRejection = case: {
    module,
    expected,
  }: let
    failure = pkgs.testers.testBuildFailure (validatorRun case module);
  in ''
    log=${failure}/testBuildFailure.log
    for want in ${lib.escapeShellArgs (expected ++ ["fixture-${case}: 1 validator run(s) rejected"])}; do
      if ! grep -qF -- "$want" "$log"; then
        echo "FAIL: the ${case} check did not report: $want" >&2
        cat "$log" >&2
        exit 1
      fi
    done
    echo "ok: the ${case} check rejects its bad config"
  '';
in {
  inherit evalHome validatorRun validatorRejection;
}
