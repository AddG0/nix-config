{lib, ...}: {
  imports = lib.flatten [
    lib.custom.suites.development.home
    lib.custom.suites.ai.home

    (with lib.custom.optional.home; [browsers comms ghostty helper-scripts])

    (with lib.custom.optional.home.development; [
      ai.ai-proxy
      ai.t3code-server
      aws
      gcloud
      grpc
      ide.jetbrains-remote
      ide.vscode-server
      postman
      terraform
      tilt
      virtualization.kubernetes
      virtualization.lens
    ])
    (with lib.custom.optional.home.secrets; [ai buf sops elevenlabs kubeconfig])
    (with lib.custom.optional.primary.development; [aws node])

    (with lib.custom.optional.home; [helper-scripts])
    (with lib.custom.optional.home.secrets; [sops])
    (with lib.custom.optional.home.services; [colima])
    (with lib.custom.optional.home.media; [
      spicetify
    ])
    (with lib.custom.optional.primary; [stylix work])
    (with lib.custom.optional.primary.secrets; [onepassword-ssh])
  ];

  # Headless: no console login, so there is no gui/<uid> domain to bootstrap into.
  launchd.agents.colima-default.domain = "user";
}
