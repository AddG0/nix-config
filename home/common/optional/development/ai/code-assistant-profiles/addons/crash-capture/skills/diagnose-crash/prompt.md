---
description: Diagnoses why a program crashed on this NixOS machine, from its systemd-coredump core dump. Reached from the crash notification or a coredumpctl PID.
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
  - Edit
  - Write
---

# Diagnosing a Crash

Work from evidence. The goal is an honest account of what happened, not a
plausible-sounding story.

## Establish the facts

`coredumpctl info <pid>` is the starting point. Beyond the backtrace, note the
**command line** the process was started with — it usually reveals what the
program was working on when it died, which is often the whole answer.

`coredumpctl list` shows whether this crash is a one-off or a pattern. Repeated
crashes of the same program, or several programs dying together, point somewhere
different than a single failure does.

## Rule out the boring causes first

Check resource exhaustion before blaming the program: `free -h`, and the journal
for OOM kills. A process killed by the OOM killer is not a bug in that process.

`SIGSYS` in particular is usually a seccomp filter rejecting a syscall, not a
memory bug — common under Wine, sandboxed browsers, and container runtimes. Chase
the filter, not the stack.

## Correlate against the timeline

The crash timestamp is the most underused piece of evidence. Compare it against:

- **Filesystem mtimes.** A directory or file whose mtime lands on the same second
  as the crash strongly suggests what triggered it.
- **The journal** around that moment, for related warnings from the same or
  neighbouring processes.
- **The last system change.** On NixOS this is a generation switch, not a package
  upgrade. `nix profile diff-closures` for home-manager, or
  `nvd diff /nix/var/nix/profiles/system-{N-1,N}-link` for the system, tells you
  what actually moved. Compare the crash time against the profile symlink mtimes
  in `/nix/var/nix/profiles/` to find which switch preceded it.

## Read the whole core, not just frame 0

Thread stacks other than the crashing one show what work was **in flight** —
thumbnailers, image loaders, IPC readers, GPU queues. That context often explains
the trigger even when the crashing frame itself cannot be symbolized.

Note any third-party code in the address space: file-manager or browser
extensions, plugins, out-of-tree drivers. In-process third-party code is a common
crash source and worth flagging — but do not pin blame on it without evidence
that it is actually implicated.

## Symbolize when you can

Store paths make this easier than on other distros: the executable path in
`coredumpctl info` names the exact derivation, so there is no ambiguity about
which build produced the crash.

```bash
core=$(mktemp -t crash-XXXXXX.core)
trap 'rm -f "$core"' EXIT
coredumpctl dump <pid> --output="$core"
gdb -q <executable> "$core" -batch -ex 'set debuginfod enabled on' -ex 'bt'
```

Do not set `DEBUGINFOD_URLS` by hand. If `services.nixseparatedebuginfod2` is
enabled the system already exports it, and if it is not, no URL will help —
there is no public debuginfod for the Nix store.

Expect unresolved frames. Nixpkgs builds most packages without a `debug` output,
and prebuilt binaries (anything `-bin`, Wine, vendored Electron) have no symbols
to fetch at all. When frames stay unresolved, **say so — never invent function
names to fill the gap.** An unsymbolized stack still has shape: which store path
each frame belongs to, and whether the crash came from a signal handler, a main
loop, or a worker thread.

A core is a verbatim copy of the process's memory and can hold passwords, tokens,
and private documents. Write it to a fresh `mktemp` path rather than a predictable
shared one, and delete it when you are done.

## Report

1. What crashed, and what it was doing at the time.
2. The most likely mechanism — separating clearly what the evidence **proves**
   from what you are **inferring**.
3. Whether any user data was lost, and where it can be recovered from. Check the
   trash before concluding anything is gone.
4. Whether it is likely to recur, and what would avoid or fix it.

Be straight about the limits of the evidence. If the cause is genuinely
ambiguous, say so rather than assembling confidence out of guesswork.

Delete the core you extracted above — it is a copy of the crashed process's
memory.

## Fixing it

The session opens in `~/nix-config`, so when the fix belongs there, make it.
Two limits, both firm:

- **Only a cause you demonstrated.** Never edit to fix a mechanism you inferred
  but did not confirm; a confident wrong fix costs far more to unwind than the
  check would have cost to run.
- **Never rebuild.** No `nixos-rebuild`, `home-manager switch`, or `nh`. Make the
  edit, say what it changes, and leave the rebuild as a deliberate step.

Leave everything else as you found it — no tidying, no unrelated refactors, no
rolling back a generation.

## Where the bug belongs

Only the third case below is yours to edit. The other two get reported, not
patched around in this config.

Most application crashes are upstream bugs in the application, not packaging
bugs. Separate the three:

- **Upstream** — the crash reproduces on the same version elsewhere. Almost all
  of them.
- **nixpkgs** — the crash comes from how the package was built or wrapped: a
  missing runtime dependency, a broken wrapper, a patch that misapplied, a
  library version skew visible in the store paths. Check whether the same program
  works from a different channel or an FHS shell before concluding this.
- **This configuration** — the crash comes from an option set in `~/nix-config`.
  Say which file and line.

State which of the three you believe it is and what evidence puts it there. If
the evidence does not distinguish them, say that instead of picking one.
