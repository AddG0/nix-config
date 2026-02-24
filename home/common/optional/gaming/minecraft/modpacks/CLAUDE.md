## Packwiz

All packwiz commands must run from inside the modpack directory. Use a `bash -c` subshell to avoid zoxide hook errors:

```bash
bash -c 'cd <modpack-dir> && packwiz list'
bash -c 'cd <modpack-dir> && packwiz modrinth install <mod> -y'
bash -c 'cd <modpack-dir> && packwiz remove <mod>'
bash -c 'cd <modpack-dir> && packwiz update --all'
bash -c 'cd <modpack-dir> && packwiz refresh'
```

## MODS.md

Always update `MODS.md` after adding or removing mods to keep it in sync with the pack.

- Mods removed temporarily (incompatible with current MC version): add to a `<!-- TODO: add back when updated for <version>: ... -->` comment above the relevant section
- Mods removed permanently: delete from the table entirely

## Minecraft Version Migration

When migrating to a new Minecraft version:

1. Run `bash -c 'cd <modpack-dir> && packwiz migrate minecraft <version>'`
2. Add old version as acceptable: `bash -c 'cd <modpack-dir> && packwiz settings acceptable-versions <old-version> -a'`
3. Test launch and fix mod incompatibilities one at a time — **always ask before removing a mod**
4. Update `pack.toml` name to reflect the new version
5. Rename the modpack directory (e.g. `main-1.21.4` → `main-1.21.11`)
6. Update the reference in `../default.nix` (instance name + source path)
7. Update the title in `MODS.md`

## Renaming a Modpack

When renaming or changing a modpack's version identity:

1. Update `name` in `pack.toml`
2. Rename the directory: `mv <old-dir> <new-dir>`
3. Update `../default.nix`: both the instance name key and the `source` path
