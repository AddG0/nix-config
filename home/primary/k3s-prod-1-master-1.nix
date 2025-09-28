{
  lib,
  config,
  ...
}: {
  imports = map lib.custom.relativeToHome [
    #################### Required Configs ####################
    "common/core" # required

    #################### Host-specific Optional Configs ####################
  ];
}
