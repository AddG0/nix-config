"""Rewrite Codex's config.toml as a real file, keeping what Codex wrote itself.

Declared settings win; anything Codex added that Nix does not manage survives
the rebuild. See programs.codex.mutableConfig for why this exists.
"""

import os
import sys
import tempfile
import tomllib

import tomli_w


def deep_merge(base, override):
    merged = dict(base)
    for key, value in override.items():
        existing = merged.get(key)
        if isinstance(value, dict) and isinstance(existing, dict):
            merged[key] = deep_merge(existing, value)
        else:
            merged[key] = value
    return merged


def read_toml(path):
    with open(path, "rb") as handle:
        return tomllib.load(handle)


def read_runtime_state(target):
    """What Codex has written, or nothing if the target is still the Nix link."""
    if not os.path.exists(target) or os.path.islink(target):
        return {}
    try:
        return read_toml(target)
    except tomllib.TOMLDecodeError as error:
        sys.exit(
            f"codex-config-merge: {target} is not valid TOML ({error}). "
            "Refusing to overwrite it — it may hold project trust worth keeping. "
            "Fix or delete the file, then re-run the activation."
        )


def write_atomically(target, contents):
    directory = os.path.dirname(target)
    os.makedirs(directory, exist_ok=True)
    handle, staged = tempfile.mkstemp(dir=directory, prefix=".config.toml.")
    try:
        with os.fdopen(handle, "wb") as stream:
            tomli_w.dump(contents, stream)
        # Codex has to be able to write it back; the store link was 0444.
        os.chmod(staged, 0o600)
        os.replace(staged, target)
    except BaseException:
        if os.path.exists(staged):
            os.unlink(staged)
        raise


def main():
    if len(sys.argv) != 3:
        sys.exit(f"usage: {sys.argv[0]} <declared.toml> <target.toml>")
    declared_path, target = sys.argv[1], sys.argv[2]

    merged = deep_merge(read_runtime_state(target), read_toml(declared_path))
    write_atomically(target, merged)


if __name__ == "__main__":
    main()
