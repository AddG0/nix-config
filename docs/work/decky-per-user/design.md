# Decky follows the user at the screen, with per-user plugin data

## Goal

Decky works for whichever user is logged in at the console (rig-pc: `gamer` in
Gaming Mode, `addg` in a desktop), and each user keeps their own plugin data:
Spotify (Deckify) and Discord (Deckcord) logins, plugin settings, logs, and CSS
Loader themes.

## Non-goals

- Two users' Decky at once. A console has one seat; the logged-in user wins.
- Per-user plugin *sets* or loader settings. Plugins and `loader.json` stay one
  declared, shared set.
- Decky for SSH or other non-console sessions.

## Current state

- Decky runs as root; before starting a plugin it drops to `UNPRIVILEGED_USER`
  with that user's groups (our `gaming/decky` patch). Jovian sets that once from
  `jovian.decky-loader.user` (`primaryDesktopUsername`).
- Upstream supports one user, fixed at install time (Decky's
  `dist/plugin_loader-release.service`); no prior art for several users was found.
- Decky splits its paths (`localplatformlinux.py`, `main.py`,
  `plugin/sandboxed_plugin.py`):
  - `PRIVILEGED_PATH`: the plugins dir and `settings/loader.json`.
  - `UNPRIVILEGED_PATH` (`DECKY_HOME`): every plugin's `settings/`, `data/`,
    `logs/`, and CSS Loader's `themes/`.
  Jovian sets only `UNPRIVILEGED_PATH=/var/lib/decky-loader`, so both resolve there.

## Design

1. **Shared half pinned:** `decky-loader` gets `PRIVILEGED_PATH=/var/lib/decky-loader`,
   so plugins and `loader.json` stay where `decky-plugin-sync` and
   `decky-settings-sync` already write them.
2. **Per-user half from env files:** `decky-loader` gets two `EnvironmentFile=`s,
   which per `systemd.exec(5)` override Jovian's `Environment=`, the later file
   winning. Each holds `UNPRIVILEGED_USER=<user>` and
   `UNPRIVILEGED_PATH=<home>/.local/share/decky`:
   - a store file for Jovian's configured (autologin) user, so boot already
     matches that user's login and restarts nothing;
   - `-/run/decky-loader/user.env`, written by the hook, absent until a login.
3. **Login hook:** a `pam_exec` session rule on the console display managers'
   PAM services (`sddm`, `sddm-autologin`, `greetd`), as root:
   - skips system users;
   - refuses a user without `<home>/.local/share/decky`, which tmpfiles creates
     user-owned for every `hostSpec.users` home (root-created, the
     dropped-privilege plugins could not write it);
   - when the user differs from the current env (`user.env`, else the boot
     file), writes `user.env` atomically and runs `systemctl restart --no-block
     decky-loader`, so login never waits on it;
   - logs to the journal under `decky-user`; failures never block login.
4. **Per-user themes:** rig-pc's CSS Loader theme (`gamepadui-theme.nix`) is
   created in each `hostSpec.users` home's `.local/share/decky/themes/` instead of
   `/var/lib/decky-loader/themes`.
5. **Restarts kill the old user's plugins:** `KillMode=mixed` instead of
   Jovian's `process`, so a plugin child such as Deckify's librespot cannot keep
   its port from the next user's.
6. **One-time migration:** `decky-loader`'s `preStart` moves each plugin's
   `settings/`, `data/`, `logs/` and `themes/` entry from `/var/lib/decky-loader`
   into the boot user's data dir, skipping any already there; `loader.json`
   stays. CSS Loader is patched to repoint a Steam `themes_custom` link left
   aimed at another themes dir.
7. Plugins already follow the user once they run as them: Deckify's PulseAudio
   socket and Deckcord's runtime dir use the real uid (our patches).

## Alternatives considered

1. **Shared data, re-owned at each switch.** Rejected by choice (2026-10-30):
   one Spotify and one Discord login for everyone.
2. **One Decky per user as a user service.** Rejected: Decky must run as root to
   drop privileges per plugin (Jovian's module comment, Decky's own
   "unprivileged ... not officially supported" warning), and Jovian ships only
   the system service.
3. **Restart from a user-level unit via polkit.** Rejected: user managers also
   start for SSH logins, so an SSH session would steal Decky from the console user.

## Risks

- Every console login restarts Decky (a few seconds without the Decky menu).
- A plugin writing outside `DECKY_HOME` (e.g. hardcoded `/home/deck`) keeps
  sharing or failing as before.
- First login per user starts plugins unconfigured (empty data dir).
- `pam_exec` on `sddm-autologin`/`greetd` must not delay or fail login; the rule
  is `optional` and the restart is `--no-block`.

## Verification

- Eval: `decky-loader` has `PRIVILEGED_PATH` and the `EnvironmentFile`; the PAM
  rule is on each console service; hosts without Decky are unchanged.
- Tests: `script:hosts:decky` runs the hook and the migration against stubbed
  `id`/`getent`/`systemctl`/`systemd-cat` and fake homes.
- On rig-pc: log in as each user; `cat /run/decky-loader/user.env`, plugin logs
  under that user's `.local/share/decky/logs/`.
