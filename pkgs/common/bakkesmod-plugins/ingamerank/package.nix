{ callPackage }:

let
  mkBakkesModPlugin = callPackage ../mk-bakkesmod-plugin.nix {};
in
mkBakkesModPlugin {
  pname = "IngameRank";
  version = "1.0.8";
  pluginId = "282";
  sha256 = "sha256-vjtCY/7fnEyTs68rDQ5dx+9Gz5S3DlsOtSaQK5leuBc=";
  description = "Shows player ranks in-game scoreboards";
}