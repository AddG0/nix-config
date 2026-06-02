{config, ...}: {
  programs.wireshark = {
    enable = true;
    dumpcap.enable = true;
  };

  users.users.${config.hostSpec.username}.extraGroups = ["wireshark"];
}
