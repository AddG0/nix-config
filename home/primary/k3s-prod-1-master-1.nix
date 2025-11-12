{lib, ...}: {
  imports = lib.flatten [
    ./common/core

    (map lib.custom.relativeToHome [
      #################### Required Configs ####################
      "common/core" # required

      #################### Host-specific Optional Configs ####################
    ])
  ];
}
