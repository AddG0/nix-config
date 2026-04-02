# Midgard Nomad cluster — server node (odin)
# Adds the server/scheduler role on top of the client config
#
# ACL Bootstrap (one-time, manual):
#   1. Ensure all servers have ACL enabled and are running
#   2. From any server: nomad acl bootstrap
#   3. Save the Secret ID — this is your management token
#   4. Add it to nix-secrets as services/nomad/acl.yaml -> acl_token
#   5. Re-encrypt with sops and deploy
{...}: {
  imports = [./client.nix];

  services.nomad.settings.server = {
    enabled = true;
    bootstrap_expect = 1;
  };
}
