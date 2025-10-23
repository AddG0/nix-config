{
  lib,
  config,
  ...
}: {
  imports = lib.flatten [
    ./common

    (map lib.custom.relativeToHome [
      #################### Required Configs ####################
      "common/core" # required

      #################### Host-specific Optional Configs ####################
    ])
  ];
}
