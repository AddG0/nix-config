{pkgs, ...}: {
  # Allow SSH config's RemoteCommand to be used.
  # Required for -vscode host aliases that work around nushell's TTY requirement.
  userSettings = {
    "remote.SSH.enableRemoteCommand" = true;
  };
}
