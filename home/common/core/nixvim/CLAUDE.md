# nixvim keybinds

Update `docs/guides/nixvim-keybinds.html` whenever a keymap here (or in
`languages/`) is added, removed, rebound, or has its `desc` changed. It's the
only reference doc — no separate markdown file.

- Data lives in the `DATA` array in the page's `<script>` block.
- Store keys literally (`<leader>ff`), not the `␣` display glyph.
- New leader group with sub-keys (e.g. `<leader>gm`)? Also add it to the
  which-key spec in `ui.nix`.
