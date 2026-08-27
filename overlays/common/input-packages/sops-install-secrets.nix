# sops-install-secrets decrypted once per secret, serially. With a remote KMS in
# the recipients every one of those is a network round trip, so activation spent
# ~18s per run doing 21 sequential calls for 13 distinct files. Patch decrypts
# each distinct file once, concurrently.
{inputs, ...}: _final: prev: {
  sops-install-secrets = (import inputs.sops-nix {pkgs = prev;}).sops-install-secrets.overrideAttrs (old: {
    patches = (old.patches or []) ++ [./sops-install-secrets-parallel-decrypt.patch];
  });
}
