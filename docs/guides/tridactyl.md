# tridactyl

Vim-style keyboard control for Zen. Configured in
`home/common/optional/browsers/zen/{tridactyl,default}.nix`. **Close Zen before
rebuilding**, then restart it (content scripts only inject into pages opened
after the extension goes live).

## Modes

Indicator sits bottom-right.

| Mode | When | Get out |
|------|------|---------|
| normal | default — keys are commands | — |
| insert | a text field is focused | `Esc` |
| hint | after `f` / `;` | type the letters, or `Esc` |
| ignore | page owns all keys | `Shift+Esc` |

## Scroll

| Key | Action |
|-----|--------|
| `j` / `k` | line down / up |
| `h` / `l` | left / right |
| `d` / `u` | half page down / up |
| `Ctrl+D` / `Ctrl+U` | half page down / up (same) |
| `Ctrl+F` / `Ctrl+B` | full page down / up |
| `gg` / `G` | top / bottom |

`default.nix` frees these from Zen's defaults (bookmark, view-source, find,
sidebar); native find moves to `Ctrl+Shift+F`.

## Follow links (hints)

| Key | Action |
|-----|--------|
| `f` / `F` | open in current / background tab |
| `;y` | yank the link's URL |
| `;t` | open in a new tab |
| `;p` | copy the element's text |
| `;i` | hint images |
| `;s` / `;S` | save link / image |
| `;r` | open in reader mode |

In hint mode: `Tab`/arrows move focus, `Enter` selects, `Backspace` undoes a letter.

## Tabs

| Key | Action |
|-----|--------|
| `J` / `K` | prev / next tab |
| `Ctrl+^` | last-used tab |
| `b` / `B` | switch tab by title (window / all windows) |
| `t` / `o` | open URL in new / current tab |
| `T` / `O` | same, prefilled with current URL |
| `x` | close tab |
| `X` / `U` | reopen closed tab / window |

## Navigate & search

| Key | Action |
|-----|--------|
| `H` / `L` | back / forward |
| `r` / `R` | reload / hard-reload |
| `Ctrl+Shift+F` | find (native bar: `Enter`/`Shift+Enter` cycle, highlight, match-case) |
| `s` / `S` | web search in current / new tab |
| `[[` / `]]` | prev / next page link |
| `gi` | focus the main text input |
| `a` | bookmark page |

Tridactyl's own `/` `?` `n` `N` find is incomplete (its docs); use `Ctrl+Shift+F`.

## Yank

| Key | Action |
|-----|--------|
| `yy` / `yt` / `ym` / `ys` | URL / title / Markdown link / short URL |

## Edit in Neovim

Native messenger pipes content into nixvim (opens in ghostty); verify with `:native`.

| Key / command | Action |
|---------------|--------|
| `Ctrl+I` | edit the focused editable field; `:wq` syncs back |
| `;e` | open any element's text (incl. read-only boxes) — read-only |
| `:clipnvim` | open the clipboard (e.g. after a page's copy button) — read-only |

Temp file is `.json`, so `:%!jq .` formats it.

## Marks & zoom

| Key | Action |
|-----|--------|
| `m{a-z}` / `` `{a-z} `` | set / jump to mark |
| `zi` / `zo` / `zz` | zoom in / out / reset |

## Command mode (`:`)

| Command | Action |
|---------|--------|
| `:tutor` | interactive tutorial — start here |
| `:help` | full searchable docs |
| `:bind <keys> <cmd>` | add a binding (session) |
| `:mode ignore` | hand all keys to the page |

## Web apps (Jira, Gmail…)

They capture keys and scroll inner containers, so `j`/`k` may fail and inputs
drop you into insert mode. `Shift+Esc` toggles ignore mode (use the app's own
shortcuts; `?` lists them), or pin it: `autocmd DocStart <domain> mode ignore`.

## Dead zones

No keybinds on `about:` pages, the new-tab page, or addons.mozilla.org — the
mode indicator is absent there.
