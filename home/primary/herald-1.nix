{
  inputs,
  lib,
  ...
}: {
  imports = lib.flatten [
    inputs.stylix.homeModules.stylix
    ./common/core

    (map lib.custom.relativeToHome (
      [
        #################### Required Configs ####################
        "common/core" # required
      ]
      ++ (map (f: "common/optional/${f}") [
        #################### Host-specific Optional Configs ####################
      ])
    ))
  ];
}
