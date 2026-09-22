{
  lib,
  mkPlugin,
}:
mkPlugin {
  pname = "obsidian-self-hosted-livesync";

  # Held behind 1.0.30 until the vault's other devices leave 0.25.x — LiveSync
  # replicates between matching majors only.
  version = "0.25.65";
  repo = "vrtmrz/obsidian-livesync";

  hashes = {
    "main.js" = "sha256-XOd8mcXoKQhlIEeX7YpES8joLDwx3TPbdYHUEBtX/xY=";
    "manifest.json" = "sha256-qjcqcA+uE/wnMO5f+o4HqwOjLooi08UhrNnxgz2e6qg=";
    "styles.css" = "sha256-4PExkKtAdimEHIjqzQ0P4AAy9Wy7L5DJjY/AU9wIlEs=";
  };

  meta = {
    description = "Self-hosted live synchronisation between Obsidian vaults";
    homepage = "https://github.com/vrtmrz/obsidian-livesync";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
