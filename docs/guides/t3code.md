# t3code

Web GUI for coding agents. Keymaps in
`home/common/optional/development/ai/t3code/keybindings.nix`.

`mod` = `Ctrl` on Linux (shown below), `⌘` on macOS. Nix binds **add to** the
defaults — the merge is per `(key, when)` and cannot unbind.

## Panels

| Key | Action | Set by |
|-----|--------|--------|
| `Ctrl+B` | toggle sidebar | default |
| `Ctrl+E` | toggle sidebar | nix |
| `Ctrl+Alt+B` | toggle right panel | default |
| `Ctrl+Shift+E` | toggle right panel | nix |
| `Ctrl+Shift+J` | toggle preview | default |

## Terminal

| Key | Action | Set by |
|-----|--------|--------|
| `Ctrl+J` | toggle | default |
| `Ctrl+\` | toggle | nix |
| `Ctrl+D` | split | default |
| `Ctrl+Shift+D` | split vertical | default |
| `Ctrl+N` | new | default |
| `Ctrl+W` | close | default |
| `Ctrl+L` | clear — hardcoded | — |
| `Ctrl+←` / `Ctrl+→` | word back / forward — hardcoded | — |

Splits need terminal focus. Unfocused, `Ctrl+D` is diff and `Ctrl+N` is new thread.

## Threads

| Key | Action | Set by |
|-----|--------|--------|
| `Ctrl+Shift+[` / `]` | previous / next | default |
| `Ctrl+Shift+H` / `L` | previous / next | nix |
| `Ctrl+1`…`9` | jump to thread 1–9 | default |
| `Enter` / `Space` | open focused sidebar row | default |

## Composer

| Key | Action |
|-----|--------|
| `Enter` | send |
| `Shift+Enter` | newline |
| `Ctrl+S` | stash draft |
| `Ctrl+N` / `Ctrl+Shift+O` | new thread |
| `Ctrl+Shift+N` | new local thread |
| `Ctrl+Shift+M` | model picker |
| `Ctrl+1`…`9` | pick model 1–9 (picker open) |
| `↑` / `↓` | move in `/` or `@` menu |
| `Enter` / `Tab` | accept menu item |
| `Shift+Tab` | Build/Plan — needs `planModeEnabled` |

Typing a bare character anywhere jumps into the composer.

## Pickers

| Key | Action | Set by |
|-----|--------|--------|
| `Ctrl+K` | command palette | default |
| `Ctrl+P` | file picker | default |
| `Ctrl+F` | file picker | nix |
| `Ctrl+Shift+F` | project search | default |
| `Ctrl+/` | project search | nix |

All require the terminal unfocused.

## Diff, editor, preview

| Key | Action | Set by |
|-----|--------|--------|
| `Ctrl+D` | toggle diff | default |
| `Ctrl+G` | toggle diff | nix |
| `Ctrl+O` | open in favorite editor | default |
| `Ctrl+Alt+Shift+T` | theme editor | default |
| `Ctrl+R` | refresh preview | default |
| `Ctrl+L` | focus preview URL | default |
| `Ctrl+=` / `Ctrl+-` | preview zoom in / out | default |
| `Ctrl+0` | preview reset zoom | default |

Preview keys require preview focus.

## Mouse only

Pin, unpin, settle, un-settle, snooze, wake, rename, regenerate title, mark
unread, copy path, copy branch, delete, new thread on branch.

Right-click a sidebar row or use the chat header menu; it is a native menu with
no keyboard route. Pinned rows expose a focusable unpin button (`Tab`+`Enter`).
Pin, settle, snooze and title regeneration are gated on server capability.

No scroll commands exist — nvim's `Ctrl+D`/`Ctrl+U` has no equivalent.

## `when` variables

`terminalFocus`, `terminalOpen`, `previewFocus`, `previewOpen`,
`modelPickerOpen`, `true`, `false`. Operators `!`, `&&`, `||`, parens.

Unknown identifiers evaluate to `false`, so typos die silently. Sidebar and chat
view only populate the terminal and model-picker ones.

## Adding a binding

Rule is `key`, `command`, optional `when`.

Key: modifiers `mod`/`cmd`/`meta`/`ctrl`/`control`/`shift`/`alt`/`option` plus
exactly one key (`space`, `esc` are aliases). Two non-modifier tokens fails, so
no `<leader>` sequences. On Linux `mod` resolves to `ctrl`, so `ctrl+x` collides
with `mod+x` — plain `ctrl+` only works on keys no default claims, like `ctrl+\`.

Commands are a closed list: `sidebar.toggle`, `rightPanel.toggle`, `diff.toggle`,
`terminal.{toggle,split,splitVertical,new,close}`,
`preview.{toggle,refresh,focusUrl,zoomIn,zoomOut,resetZoom}`,
`commandPalette.toggle`, `filePicker.toggle`, `projectSearch.toggle`,
`themeEditor.toggle`, `composer.stash`, `chat.new`, `chat.newLocal`,
`editor.openFavorite`, `modelPicker.toggle`, `modelPicker.jump.1`–`9`,
`thread.previous`, `thread.next`, `thread.jump.1`–`9`, `script.<id>.run`.

An unknown command fails the whole file, stranding every binding in it.
