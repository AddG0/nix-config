# One-way dependencies between the shared profile model, the targets and the tool modules.
{
  expect,
  lib,
  ...
}: let
  nixFilesIn = dir: lib.filter (lib.hasSuffix ".nix") (lib.attrNames (builtins.readDir dir));
  # The shared model, its options and its tests, bar the module wiring and this file, which names the paths it forbids.
  modelFiles = lib.filter (file: !(lib.elem file ["default.nix" "tests/structure.nix"])) (nixFilesIn ./.. ++ lib.concatMap (dir: map (file: "${dir}/${file}") (nixFilesIn (./.. + "/${dir}"))) ["options" "tests"]);
  importsAcross = text: lib.any (needle: lib.hasInfix needle text) ["targets/" "../claude-code" "../codex"];
  modelImportViolations = lib.filter (file: importsAcross (builtins.readFile (./.. + "/${file}"))) modelFiles;
  toolModuleFiles = dir: map (file: dir + "/${file}") (lib.filter (file: lib.hasSuffix ".nix" file && file != "tests.nix") (lib.attrNames (builtins.readDir dir)));
  toolImportViolations =
    lib.filter (file: lib.hasInfix "code-assistant-profiles" (builtins.readFile file))
    (toolModuleFiles ../../claude-code ++ toolModuleFiles ../../codex);
  # A target's render reads only the shared model; its tool's hook schema arrives as an argument.
  renderFiles = map (target: ../targets/${target}/render.nix) ["claude-code" "codex" "opencode"];
  renderImportViolations = lib.filter (file: lib.any (needle: lib.hasInfix needle (builtins.readFile file)) ["../../../" "../claude-code" "../codex" "../opencode" "./default.nix" "./options.nix"]) renderFiles;
in ''
  ${expect "the shared profile model imports nothing from targets or tool modules" modelImportViolations []}
  ${expect "the dependency check flags an import of a target" (importsAcross "import ./targets/codex/default.nix") true}
  ${expect "the claude-code and codex tool modules import nothing from code-assistant-profiles" toolImportViolations []}
  ${expect "the dependency check reads the shared model files" (lib.all (file: lib.elem file modelFiles) ["resolve-profile.nix" "options/default.nix" "options/profile.nix" "options/skill.nix" "options/fields.nix" "validation.nix" "tests/default.nix" "tests/fixtures.nix"]) true}
  ${expect "the dependency check reads the claude-code and codex tool module files" (map (file: lib.any (lib.hasSuffix file) (map toString (toolModuleFiles ../../claude-code ++ toolModuleFiles ../../codex))) ["/claude-code/default.nix" "/codex/default.nix"]) [true true]}
  ${expect "each target's render imports nothing beyond the shared model" renderImportViolations []}
  ${expect "the render check reads every target's render file" (map builtins.pathExists renderFiles) [true true true]}

''
