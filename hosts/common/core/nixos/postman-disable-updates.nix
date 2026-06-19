_:
# Postman is pinned via Nix and lives in the read-only store, so its
# self-updates can never install. Null-route the update CDN to stop the
# background checks/downloads and the "update available" nag (the in-app
# toggle doesn't stop minor updates: https://github.com/postmanlabs/postman-app-support/issues/7944).
{
  networking.extraHosts = "127.0.0.1 dl.pstmn.io";
}
