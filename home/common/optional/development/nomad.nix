# Nomad CLI environment — sets NOMAD_ADDR and loads ACL token
{
  config,
  inputs,
  pkgs,
  ...
}: {
  sops.secrets.nomad_acl_token = {
    sopsFile = "${inputs.nix-secrets}/services/nomad/acl.yaml";
    key = "acl_token";
  };

  home = {
    packages = [pkgs.nomad];
    sessionVariables = {
      NOMAD_ADDR = "http://odin:4646";
    };
  };

  home.shellAliases = {
    # Jobs
    nr = "nomad job run";
    nrd = "nomad job run -detach";
    ns = "nomad status";
    njs = "nomad job status";
    nstop = "nomad job stop";
    np = "nomad job plan";

    # Logs & debugging
    nl = "nomad alloc logs";
    nlf = "nomad alloc logs -f";
    nas = "nomad alloc status";

    # Cluster
    nn = "nomad node status";
    nsm = "nomad server members";
  };

  programs.zsh.initContent = ''
    export NOMAD_TOKEN="$(cat "${config.sops.secrets.nomad_acl_token.path}")"
    complete -o nospace -C ${pkgs.nomad}/bin/nomad nomad
  '';
}
