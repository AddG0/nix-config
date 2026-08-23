# Adds Neovim to t3code's "Open in" picker, whose editor list is a closed table
# in the source with no config hook. Both the contracts table and the picker's
# own hardcoded options need the entry, or the editor launches but never shows.
#
# Chained through theme.basePackage so both patches land in one derivation —
# disabling the theme would drop this too.
{
  config,
  lib,
  pkgs,
  ...
}: let
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

  pickerAnchor = "    {\n      label: isMacPlatform(platform)\n        ? \"Finder\"";
  pickerEntry = "    {\n      label: \"Neovim\",\n      Icon: TerminalIcon,\n      value: \"nvim\",\n      kind: \"generic\",\n    },\n";

  withNvim = pkgs.t3code.override {
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
in
  lib.mkIf (pkgs.stdenv.hostPlatform.isLinux && config.hostSpec.hostType != "server") {
    programs.t3code.theme.basePackage = withNvim;
  }
