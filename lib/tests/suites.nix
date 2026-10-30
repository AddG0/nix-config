# lib.custom.suitesFromDeclarations/useSuite: shared trees feed `nixos`/`home`, each user tree its own `users.<tree>` half.
{lib, ...}: let
  inherit (lib.custom) suitesFromDeclarations useSuite;
  declared = tree: value: {
    inherit tree;
    declare = _: value;
  };
  suites = suitesFromDeclarations {} [
    (declared "hosts" {desk.nixos = ["host-desk"];})
    (declared "home" {desk.home = ["home-desk"];})
    (declared "primary" {
      desk.home = ["primary-desk"];
      mine.home = ["primary-only"];
    })
  ];
  # The home-manager users a host import of `suite` configures, on a host with these hostSpec users and accounts.
  homesFor = hostUsers: accounts: suite:
    lib.mapAttrs (_: home: home.imports)
    ((lib.last (useSuite suite)) {
      config = {
        hostSpec = {
          primaryUsername = "u";
          users = hostUsers;
        };
        users.users = lib.genAttrs accounts (_: {});
      };
    }).home-manager.users;
  homesOn = homesFor ["u"];
  homeImports = suite: (homesOn ["u"] suite).u;
  twoUsers = (suitesFromDeclarations {} [(declared "primary" {desk.home = ["a"];}) (declared "guest" {desk.home = ["b"];})]).desk;
in {
  testFilesAUserTreesHomeHalfUnderThatUser = {
    expr = suites.desk;
    expected = {
      nixos = ["host-desk"];
      home = ["home-desk"];
      users.primary = ["primary-desk"];
    };
  };

  testAllowsASuiteOnlyAUserTreeDeclares = {
    expr = suites.mine;
    expected = {users.primary = ["primary-only"];};
  };

  testImportsHomeAndPrimaryHalvesIntoThePrimaryUser = {
    expr = homeImports suites.desk;
    expected = ["home-desk" "primary-desk"];
  };

  testImportsTheSharedHomeHalfIntoEveryHostUser = {
    expr = homesFor ["u" "d"] ["u" "d"] suites.desk;
    expected = {
      u = ["home-desk" "primary-desk"];
      d = ["home-desk"];
    };
  };

  testKeepsTheNixosHalfOnTheHost = {
    expr = builtins.head (useSuite suites.desk);
    expected = "host-desk";
  };

  testRefusesANixosHalfFromThePrimaryTree = {
    expr = builtins.deepSeq (suitesFromDeclarations {} [(declared "primary" {desk.nixos = ["x"];})]) null;
    expectedError = {
      type = "ThrownError";
      msg = "suite desk: user tree primary declares only `home` halves, got nixos";
    };
  };

  testKeepsEachUserTreesHalfSeparate = {
    expr = (suitesFromDeclarations {} [(declared "primary" {desk.home = ["a"];}) (declared "guest" {desk.home = ["b"];})]).desk;
    expected.users = {
      primary = ["a"];
      guest = ["b"];
    };
  };

  testImportsAnotherUserTreeIntoThatUserWhenTheHostHasThem = {
    expr = homesOn ["u" "guest"] twoUsers;
    expected = {
      u = ["a"];
      guest = ["b"];
    };
  };

  testSkipsAUserTreeOnAHostWithoutThatUser = {
    expr = homesOn ["u"] twoUsers;
    expected.u = ["a"];
  };

  testAddsATreeNamedAfterThePrimaryUserToTheirImports = {
    expr = homesOn ["u"] (suitesFromDeclarations {} [(declared "home" {desk.home = ["shared"];}) (declared "primary" {desk.home = ["a"];}) (declared "u" {desk.home = ["c"];})]).desk;
    expected.u = ["shared" "a" "c"];
  };

  testRefusesTheSameHalfFromTwoFiles = {
    expr = builtins.deepSeq (suitesFromDeclarations {} [(declared "home" {desk.home = ["a"];}) (declared "home" {desk.home = ["b"];})]) null;
    expectedError = {
      type = "ThrownError";
      msg = "suite desk: home defined in more than one _suites.nix";
    };
  };
}
