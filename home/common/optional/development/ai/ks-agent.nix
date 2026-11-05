# Sends coding-agent sessions to the knowledge server for ingestion.
{
  config,
  inputs,
  ...
}: {
  imports = [inputs.ks-agent.homeManagerModules.ks-agent];

  services.ks-agent = {
    enable = true;
    serverAddr = "https://ingest.${config.hostSpec.domain}";
  };
}
