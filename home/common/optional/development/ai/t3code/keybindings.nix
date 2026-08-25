# Echoes the nvim maps in home/common/core/nixvim, each comment naming its
# origin. parseKeybindingShortcut takes modifiers plus one key, so leader
# sequences like <leader>ff have no equivalent here.
#
# Reassigning a chord t3code already binds would strand that command: the
# activation merge is per (key, when) and cannot unbind. These all take free
# chords. <leader>1..9 harpoon already matches the mod+1..9 default.
#
# STATIC_KEYBINDING_COMMANDS in packages/contracts is a closed union, so nvim's
# <C-d>/<C-u> half-page scroll and thread pin/unpin have nothing to bind to --
# pin lives only in the sidebar and chat-header menus. KeybindingsConfig is a
# plain Schema.Array, so an unknown command fails the whole keybindings.json
# parse rather than dropping its own rule; adding them on spec would strand
# every binding below.
_: {
  programs.t3code.keybindings = [
    # <C-\> Snacks.terminal. ctrl, not mod, so it stays Ctrl on darwin too.
    {
      key = "ctrl+\\";
      command = "terminal.toggle";
    }

    # <S-h>/<S-l> and [b/]b buffer nav; threads are t3code's buffers.
    {
      key = "mod+shift+h";
      command = "thread.previous";
    }
    {
      key = "mod+shift+l";
      command = "thread.next";
    }

    # <leader>e Snacks.explorer
    {
      key = "mod+e";
      command = "sidebar.toggle";
    }

    # <leader>cs Trouble symbols, nvim's right-side panel. Shifted counterpart
    # to mod+e above; the mod+alt+b default stays bound but is a poor reach.
    {
      key = "mod+shift+e";
      command = "rightPanel.toggle";
    }

    # <leader>ff and <leader><space> Snacks.picker.files
    {
      key = "mod+f";
      command = "filePicker.toggle";
      when = "!terminalFocus";
    }

    # <leader>/ and <leader>sg Snacks.picker.grep
    {
      key = "mod+/";
      command = "projectSearch.toggle";
      when = "!terminalFocus";
    }

    # <leader>gd and <leader>gv git diff
    {
      key = "mod+g";
      command = "diff.toggle";
      when = "!terminalFocus";
    }
  ];
}
