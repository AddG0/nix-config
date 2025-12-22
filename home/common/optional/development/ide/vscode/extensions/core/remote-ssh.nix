{pkgs, ...}: {
  extensions = [
    pkgs.vscode-marketplace.ms-vscode-remote.remote-ssh
  ];
  userSettings = {
    # Required for -vscode host aliases that use RemoteCommand for nushell workaround
    "remote.SSH.enableRemoteCommand" = true;
    "remote.SSH.path" = "${pkgs.openssh}/bin/ssh";
  };
}
