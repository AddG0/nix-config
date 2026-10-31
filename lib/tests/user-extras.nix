# lib.custom.withUserExtras/importUserHome: a user tree's module at a shared home module's place rides along with it.
{lib, ...}: let
  inherit (lib.custom) importUserHome optional useSuite withUserExtras;
  # The imports of a user home file, as the module system sees them.
  userHomeImports = tree: file: ((importUserHome tree file) {inherit lib;}).imports;
  # The home-manager imports a host import of `suite` gives each user, with `u` the primary user.
  suiteImports = users: suite:
    lib.mapAttrs (_: home: home.imports)
    ((lib.last (useSuite suite)) {
      config = {
        hostSpec = {
          primaryUsername = "u";
          inherit users;
        };
        users.users = lib.genAttrs users (_: {});
      };
    }).home-manager.users;

  # Paths a user tree shares with the shared home tree where one side is a module and the other a namespace.
  mismatches = shared: own: prefix:
    lib.concatLists (lib.mapAttrsToList (name: here: let
      there = shared.${name} or null;
      path = prefix ++ [name];
    in
      if there == null || (builtins.isPath here && builtins.isPath there)
      then []
      else if builtins.isAttrs here && builtins.isAttrs there
      then mismatches there here path
      else [(lib.concatStringsSep "." path)])
    own);
  userTrees = builtins.attrNames (removeAttrs optional ["hosts" "home"]);
in {
  testAddsTheUserTreesModuleAtTheSamePlace = {
    expr = withUserExtras "primary" [optional.home.browsers];
    expected = [optional.home.browsers optional.primary.browsers];
  };

  testFindsTheExtraForANestedModule = {
    expr = withUserExtras "primary" [optional.home.development.aws];
    expected = [optional.home.development.aws optional.primary.development.aws];
  };

  testAddsNothingWhenTheUserTreeHasNoModuleThere = {
    expr = withUserExtras "primary" [optional.home.comms];
    expected = [optional.home.comms];
  };

  testAddsNothingForAUserWithoutATree = {
    expr = withUserExtras "nobody" [optional.home.browsers];
    expected = [optional.home.browsers];
  };

  testLeavesImportsOutsideTheSharedHomeTreeAlone = {
    expr = withUserExtras "primary" ["/elsewhere/browsers" optional.primary.stylix];
    expected = ["/elsewhere/browsers" optional.primary.stylix];
  };

  testExpandsTheNestedImportListOfAUserHomeFile = {
    expr = userHomeImports "primary" ./_user-home.nix;
    expected = [optional.home.browsers optional.home.comms optional.primary.browsers];
  };

  testExpandsAUserHomeFileWrittenAsAPlainAttrset = {
    expr = (importUserHome "primary" ./_user-home-attrs.nix).imports;
    expected = [optional.home.browsers optional.primary.browsers];
  };

  testKeysAUserHomeFileByItsPathSoItDedupesWithAPlainImport = {
    expr = ((importUserHome "primary" ./_user-home.nix) {inherit lib;}).key;
    expected = toString ./_user-home.nix;
  };

  testGivesOnlyTheUserWithATreeTheirExtraFromASuitesHomeHalf = {
    expr = suiteImports ["u" "guest"] {home = [optional.home.browsers];};
    expected = {
      u = [optional.home.browsers optional.primary.browsers];
      guest = [optional.home.browsers];
    };
  };

  testLoadsAUserCoreDirectoryKeyedByThatDirectory = {
    expr = ((importUserHome "primary" ../../home/primary/common/core) {inherit lib;}).key;
    expected = toString ../../home/primary/common/core;
  };

  testEveryUserTreePairsModulesWithModulesAndNamespacesWithNamespaces = {
    expr = lib.concatMap (tree: map (path: "${tree}: ${path}") (mismatches optional.home optional.${tree} [])) userTrees;
    expected = [];
  };
}
