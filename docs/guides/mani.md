# mani

Run tasks across many repos. Source: [`home/common/optional/development/polyrepo/mani.nix`](../../home/common/optional/development/polyrepo/mani.nix).

## The two configs

| File | Owner | Holds |
|---|---|---|
| `~/.config/mani/config.yaml` | **nix** (this module) | `shell`, themes, reusable tasks |
| `<repo-tree>/mani.yaml` | **you** (`mani init`) | `projects:` list for that tree |

mani loads both. To add a new tree: `cd <root> && mani init`.

## Cheat sheet

```sh
mr gst                      # all projects (default for read-only tasks)
mr gst -k                   # override → current project only
mr gst -d <prefix>          # override → subtree by path prefix
mr gl  -k                   # pull current project (sequential, no default)

me -k    -- git status      # ad-hoc on current project
me -a -f 8 --parallel -- git fetch     # ad-hoc bulk read
me -p <project> -- git log -1
me -d <prefix> -- git status   # path-prefix filter

ml projects -t <tag>        # list projects (with --tags etc.)
msy --status                # what's missing on disk?
msy --parallel              # clone everything in the yaml
```

Read-only tasks (`gst`, `gf`, `branch`) default to **all projects**. Mutating ones (`gl`, and anything you add later that pushes/rebases) have **no default** — they error until you pass `-k`/`-a`/etc. Keeps `mr gp` from fanning a push out to every repo by accident.

Aliases: `mr`=run, `me`=exec, `ml`=list, `msy`=sync.

## Pick a target — one of:

| Flag | Means |
|---|---|
| `-k` | current dir's project |
| `-a` | every project in the yaml |
| `-p <name>` | by project name |
| `-d <path>` | path-prefix filter |
| `-t <tag>` | by tag (add `tags:` to your projects first) |

No target = "no matching projects found". Deliberate — keeps you from accidentally fanning destructive ops out across the whole tree.

## Add a task

Edit [`mani.nix`](../../home/common/optional/development/polyrepo/mani.nix), `home-manager switch`, done:

```nix
tasks = {
  rebase = {
    desc = "rebase onto origin/main";
    cmd = "git fetch origin && git rebase origin/main";
  };
};
```

Then: `mr rebase -k`.

## Parallel vs sequential

Two specs are defined:

| Spec | When to use |
|---|---|
| `default` (sequential) | Anything that may prompt for auth, push, rebase, or mutate shared state. Default for new tasks. |
| `fast` (parallel, forks=8) | Read-only ops — `status`, `fetch`, `log`. Opt in with `spec = "fast";` on the task. |

`mani exec` ignores both — pass `-f 8 --parallel` per invocation, or skip it for live output.

## Gotchas

- **`-d ./` doesn't mean cwd** — it's a path filter against `path:` fields. Use `-k`.
- **`mani sync` only clones**, never pulls. For pulls, write a task.
- **Tags are empty** until you add `tags: [foo]` to projects in your `mani.yaml`.

## More

`mani <cmd> --help` · [manicli.com](https://manicli.com)
