# The dev-cloud CLI: sign in, then invite and remove GPU workers.
{
  inputs,
  pkgs,
  ...
}: {
  home.packages = [
    inputs.dev-cloud.packages.${pkgs.stdenv.hostPlatform.system}.dev-cloud
  ];
}
