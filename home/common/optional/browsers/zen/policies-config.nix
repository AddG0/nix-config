let
  mkLockedAttrs = builtins.mapAttrs (_: value: {
    Value = value;
    Status = "locked";
  });
in {
  AutofillAddressEnabled = true;
  AutofillCreditCardEnabled = false;
  DisableAppUpdate = true;
  DisableFeedbackCommands = true;
  DisableFirefoxStudies = true;
  DisablePocket = true;
  DisableTelemetry = true;
  DontCheckDefaultBrowser = true;
  NoDefaultBookmarks = true;
  OfferToSaveLogins = false;
  EnableTrackingProtection = {
    Value = true;
    Locked = true;
    Cryptomining = true;
    Fingerprinting = true;
  };
  SanitizeOnShutdown = {
    FormData = true;
    Cache = true;
  };
  Preferences = mkLockedAttrs {
    "browser.aboutConfig.showWarning" = false;
    "browser.tabs.warnOnClose" = false;
    "media.videocontrols.picture-in-picture.video-toggle.enabled" = true;
    "browser.gesture.swipe.left" = "";
    "browser.gesture.swipe.right" = "";
    "browser.tabs.hoverPreview.enabled" = true;
    "browser.newtabpage.activity-stream.feeds.topsites" = false;
    "browser.topsites.contile.enabled" = false;

    "privacy.trackingprotection.enabled" = true;
    "privacy.trackingprotection.socialtracking.enabled" = true;
    "dom.security.https_only_mode" = true;

    "gfx.webrender.all" = true;

    # WORKAROUND: Firefox's HTTP/3 (QUIC) stack hangs on some Cloudflare-fronted
    # sites (e.g. app.monarch.com — the page spins forever despite tcpdump showing
    # healthy bidirectional QUIC traffic). Affects vanilla Firefox too, not Zen-
    # specific. Chrome and curl unaffected (different QUIC implementations).
    # Tracking: https://bugzilla.mozilla.org/show_bug.cgi?id=1700703
    # Once fixed upstream: delete the `= false` line, uncomment the `= true` line.
    # "network.http.http3.enabled" = true;
    "network.http.http3.enabled" = false;

    # WORKAROUND: TLS 1.3 hybridized Kyber post-quantum keyshare produces a
    # ClientHello large enough to be silently dropped on some network paths,
    # causing connections to hang. Reported with VPNs and certain CDN edges.
    # Refs: https://community.f-secure.com/en/discussion/128867
    #       https://blog.boll.ch/webserver-are-suddenly-not-reachable-anymore-due-to-tls-1-3-hybridized-kyber-support/
    # Once unaffected upstream/network-side: delete `= false`, remove this block.
    "security.tls.enable_kyber" = false;

    # Auto-enable sideloaded extensions (installed via extensions.packages)
    # Default 15 = auto-disable all scopes; 0 = auto-enable all
    "extensions.autoDisableScopes" = 0;
  };
}
