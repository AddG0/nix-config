# Decky Loader plugins
pkgs: let
  mkStorePlugin = pkgs.callPackage ./store-plugin.nix {};
in {
  deckcord = pkgs.callPackage ./deckcord {};

  steamgriddb = mkStorePlugin {
    pname = "decky-steamgriddb";
    version = "1.7.1";
    hash = "6d6eca184677dc9ff7736439ee7a575ca8ab386c5ffb1627d446bc43dbd1ecf3";
    meta.description = "Manage custom library artwork from Gaming Mode";
  };

  protondb-badges = mkStorePlugin {
    pname = "protondb-decky";
    version = "1.2.0";
    hash = "54fadb8faec26bb8667a6fd7c61167bc4e5584414f142ae455c74a381ee23891";
    meta.description = "Tappable ProtonDB compatibility badges on game pages";
  };

  tabmaster = mkStorePlugin {
    pname = "TabMaster";
    version = "2.15.0";
    hash = "bd77e1b8b97da1603e36f3fd8d91caf3b48932a353ffbaca3e91749dc266328f";
    meta.description = "Custom library tabs, filtering and organization";
  };

  hltb = mkStorePlugin {
    pname = "hltb-for-deck";
    version = "2.0.9";
    hash = "a5547a4ad99a6d63d475476396359a4f89fc8aacdf1e9deca0015d9f4ab9751d";
    meta.description = "HowLongToBeat completion times in the library";
  };

  css-loader = mkStorePlugin {
    pname = "SDH-CssLoader";
    version = "2.1.2";
    hash = "1a1e8f4dded8494febe56df16429ef5bba1e5b8feb3fd989d5808fbef0d71350";
    meta.description = "Theme the Steam UI with DeckThemes CSS";
  };
}
