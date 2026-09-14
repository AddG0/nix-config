# t3code overlays

One file per change, each a standalone overlay that layers another
`prev.t3code.override` onto the last.

Source patches land in `unwrapped`, never on the `t3code` symlinkJoin: stdenv
skips fixupPhase when `buildCommand` is set, so postFixup on the join is a silent
no-op, the built bin.mjs has null bytes substituteInPlace refuses, and the join
bakes its postBuild into that buildCommand too — so overrideAttrs reaches neither
phase.

Anchors use `--replace-fail`, so a version bump that moves the patched code fails
the build instead of quietly dropping the change. Each file's header says what
has to be true upstream before it can be deleted.
