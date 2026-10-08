{
  pkgs,
  config,
  lib,
  ...
}: let
  mkPlugin = import ../_mk-plugin.nix {inherit pkgs lib;};
  queryUsage = pkgs.writeShellApplication {
    name = "noctalia-ai-usage-query";
    runtimeInputs = [pkgs.curl pkgs.jq];
    text = ''
      token=$(cat ${config.sops.secrets."ai/grafana-token".path})
      endpoint='https://grafana.addg0.com/api/datasources/proxy/uid/mimir/api/v1/query'

      # Header via stdin config, so the token stays out of curl's argv.
      query() {
        printf 'header = "Authorization: Bearer %s"\n' "$token" \
          | curl --config - --fail --silent --show-error --get \
            --data-urlencode "query=$1" \
            "$endpoint"
      }

      # Assigned first so a failed query aborts the script (errexit skips $() in arguments).
      usage=$(query 'ai_proxy_quota_utilization_ratio')
      resets=$(query 'ai_proxy_quota_resets_at_timestamp_seconds')
      status=$(query 'ai_proxy_quota_status')
      over_used=$(query 'ai_proxy_overage_used_dollars')
      over_limit=$(query 'ai_proxy_overage_limit_dollars')
      available=$(query 'ai_proxy_account_available')
      model_usage=$(query 'ai_proxy_model_quota_utilization_ratio')
      model_resets=$(query 'ai_proxy_model_quota_resets_at_timestamp_seconds')

      jq -cn \
        --argjson usage "$usage" \
        --argjson resets "$resets" \
        --argjson status "$status" \
        --argjson overUsed "$over_used" \
        --argjson overLimit "$over_limit" \
        --argjson available "$available" \
        --argjson modelUsage "$model_usage" \
        --argjson modelResets "$model_resets" \
        -f ${./report.jq}
    '';
  };
in {
  xdg.dataFile = mkPlugin {
    dir = ./.;
    files = ["service.luau" "widget.luau" "panel.luau"];
    templates."service.luau" = {usageQuery = lib.getExe queryUsage;};
  };

  sops.secrets."ai/grafana-token" = {};

  programs.noctalia.settings = {
    plugins.enabled = ["addg/ai-usage"];
    bar.main.end = lib.mkBefore ["ai_usage"];
    widget.ai_usage.type = "addg/ai-usage:limits";
  };
}
