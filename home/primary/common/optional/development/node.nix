# npm auth for the personal gitlab.com group. Carries this user's PAT, so it
# must not move into the shared languages/node.nix. Each repo maps its own
# @scope; only the credential lives here.
{
  config,
  lib,
  ...
}: {
  config = lib.mkIf (!config.hostSpec.disableSops) {
    # personal.yaml is the home-manager defaultSopsFile.
    sops.secrets.addg09_gitlab_token = {};

    programs.directoryEnv.rules = [
      {
        paths = ["${config.home.homeDirectory}/Projects/code/gitlab.com/addg09"];
        env = {
          # Supplies the /api/v4 _authToken in the shared npm settings.
          GITLAB_NPM_TOKEN = "$(cat ${config.sops.secrets.addg09_gitlab_token.path})";
          # Also feeds TF_TOKEN_gitlab_com via infra-live's .envrc, and glab.
          GITLAB_TOKEN = "$(cat ${config.sops.secrets.addg09_gitlab_token.path})";
        };
      }
    ];
  };
}
