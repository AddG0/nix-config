{
  inputs,
  config,
  ...
}: {
  sops.secrets."elevenlabs/api_key".sopsFile = "${inputs.nix-secrets}/global/api-keys/elevenlabs.yaml";

  programs.zsh.initContent = ''
    export ELEVENLABS_API_KEY=$(cat ${config.sops.secrets."elevenlabs/api_key".path})
  '';
}
