# Echoes the nvim maps in home/common/core/nixvim, each comment naming its
# origin. parseKeybindingShortcut takes modifiers plus one key, so leader
# sequences like <leader>ff have no equivalent here.
#
# Reassigning a chord t3code already binds would strand that command: the
# activation merge is per (key, when) and cannot unbind. These all take free
# chords. <leader>1..9 harpoon already matches the mod+1..9 default.
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
