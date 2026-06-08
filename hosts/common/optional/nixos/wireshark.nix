{config, ...}: {
  programs.wireshark = {
    enable = true;
    dumpcap.enable = true;
  };

  users.users.${config.hostSpec.primaryUsername}.extraGroups = ["wireshark"];
}
