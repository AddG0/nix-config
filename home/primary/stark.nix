{
  lib,
  config,
  ...
}: {
  imports = lib.flatten [
    ./common

    (map lib.custom.relativeToHome (
      [
        #################### Required Configs ####################
        "common/core" # required
      ]
    ++ (map (f: "common/optional/${f}") [
      #################### Host-specific Optional Configs ####################
      "helper-scripts"
      "jupyter-notebook"
    ])
    ))
  ];
}
