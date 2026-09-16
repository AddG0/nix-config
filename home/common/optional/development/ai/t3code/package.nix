# t3code package overrides that read this user's config, so cannot live in overlays/.
{
  config,
  lib,
  pkgs,
  ...
}: let
  # t3code runs glab itself with the server's env, so the per-tree token a shell would export is missing.
  withScopedGlab = pkgs.t3code.override {
    glab = config.programs.directoryEnv.wrap (lib.getExe pkgs.glab);
  };

  # ghostty rules the nvim picker entry out on a headless host.
  nvimPickerSupported = pkgs.stdenv.hostPlatform.isLinux && config.hostSpec.hostType != "server";

  t3code-nvim = pkgs.writeShellApplication {
    name = "t3code-nvim";
    runtimeInputs = with pkgs; [ghostty bash coreutils];
    text = builtins.readFile ./scripts/t3code-nvim.sh;
  };

  # Anchors carry their real indentation: '' blocks would strip the common
  # indent and stop matching.
  #
  # An absolute path skips the PATH walk in shell.resolveCommandPath, so the
  # wrapper needs no place on the server's PATH.
  editorEntry = "  { id: \"nvim\", label: \"Neovim\", commands: [\"${lib.getExe t3code-nvim}\"], launchStyle: \"direct-path\" },";
  # Doubles as the insertion point, putting nvim last but for the file manager:
  # editorPreferences defaults to the first available entry, and an editor
  # already on PATH should keep winning.
  fileManagerEntry = "  { id: \"file-manager\", label: \"File Manager\", commands: null, launchStyle: \"direct-path\" },";

  lucideImport = "import { ChevronDownIcon, FolderClosedIcon } from \"lucide-react\";";
  lucideImportWithTerminal = "import { ChevronDownIcon, FolderClosedIcon, TerminalIcon } from \"lucide-react\";";

  # Labels come from the contracts EDITORS list since 0.0.38, so the picker entry
  # needs none of its own.
  pickerAnchor = "    {\n      Icon: FolderClosedIcon,\n      value: \"file-manager\",\n      kind: \"generic\",\n    },";
  pickerEntry = "    {\n      Icon: TerminalIcon,\n      value: \"nvim\",\n      kind: \"generic\",\n    },\n";

  # The "Open in" editor list is closed: the contracts table and the picker both need the entry.
  withNvim = withScopedGlab.override {
    t3code-unwrapped = pkgs.t3code.unwrapped.overrideAttrs (old: {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace packages/contracts/src/editor.ts \
            --replace-fail ${lib.escapeShellArg fileManagerEntry} ${lib.escapeShellArg "${editorEntry}\n${fileManagerEntry}"}

          substituteInPlace apps/web/src/components/chat/OpenInPicker.tsx \
            --replace-fail ${lib.escapeShellArg lucideImport} ${lib.escapeShellArg lucideImportWithTerminal} \
            --replace-fail ${lib.escapeShellArg pickerAnchor} ${lib.escapeShellArg "${pickerEntry}${pickerAnchor}"}
        '';
    });
    # Pinned to avoid a Rust rebuild for an identical binary.
    t3code-resource-monitor = pkgs.t3code.resourceMonitor;
  };
in {
  # The theme module owns basePackage, so disabling it drops these too.
  programs.t3code.theme.basePackage =
    if nvimPickerSupported
    then withNvim
    else withScopedGlab;
}
