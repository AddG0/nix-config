{inputs, ...}: final: _prev: {
  stable = import inputs.nixpkgs-stable {
    inherit (final.stdenv.hostPlatform) system;
  };
  unstable = import inputs.nixpkgs-unstable {
    inherit (final.stdenv.hostPlatform) system;
    inherit (final) config;
  };
  nur = import inputs.nur {
    pkgs = final;
    nurpkgs = final;
  };
}
