# A preview automation request that goes unanswered for 15s makes the server's
# PreviewAutomationBroker drop the host connection by shutting its queue. That
# ends the `previewAutomation.connect` stream with an interrupt, and client
# subscriptions only resubscribe on a new websocket session, so the window stays
# unregistered ("No preview automation host is available") until t3code
# restarts. Logging the end and repeating the stream re-registers the host under
# a fresh connectionId; the timed-out request has already failed, so nothing is
# replayed. Drop once upstream resubscribes an ended automation stream.
#
# Patched in `unwrapped`: see README.md.
_: _final: prev: let
  inherit (prev.lib) escapeShellArg;

  importAnchor = ''import { Atom } from "effect/unstable/reactivity";'';
  importPatch = ''
    import * as Cause from "effect/Cause";
    import * as Effect from "effect/Effect";
    import * as Schedule from "effect/Schedule";
    import * as Stream from "effect/Stream";
    import { Atom } from "effect/unstable/reactivity";'';

  streamAnchor = "tag: WS_METHODS.previewAutomationConnect,";
  streamPatch = ''
    tag: WS_METHODS.previewAutomationConnect,
          transform: (stream) =>
            stream.pipe(
              Stream.catchCause((cause) =>
                Stream.fromEffect(
                  Effect.logWarning("Preview automation host connection ended; reconnecting.", {
                    cause: Cause.pretty(cause),
                  }),
                ).pipe(Stream.drain),
              ),
              Stream.repeat(Schedule.spaced("1 second")),
            ),'';
in {
  t3code = prev.t3code.override {
    t3code-unwrapped = prev.t3code.unwrapped.overrideAttrs (old: {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace packages/client-runtime/src/state/preview.ts \
            --replace-fail ${escapeShellArg importAnchor} ${escapeShellArg importPatch} \
            --replace-fail ${escapeShellArg streamAnchor} ${escapeShellArg streamPatch}
        '';
    });
    # Pinned to avoid a Rust rebuild for an identical binary.
    t3code-resource-monitor = prev.t3code.resourceMonitor;
  };
}
