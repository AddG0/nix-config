# checks/discovery.nix: how a tests dir becomes check names, on an in-memory tree.
{lib, ...}: let
  inherit (import ../discovery.nix {inherit lib;}) discover testCount withTests;

  # A directory listing per path; anything absent is an empty directory.
  readDirOf = tree: path: tree.${toString path} or {};

  namesOf = tree: roots:
    map (test: test.name) (discover {
      inherit roots;
      readDir = readDirOf tree;
    });

  forced = value: builtins.deepSeq value value;

  # The fixture tree with the gradle module's tests dir replaced.
  gradleTests = listing: extra: forced (namesOf (tree // {"/fake/modules/gradle/tests" = listing;} // extra) moduleRoot);

  flatRoot = {
    lib = {
      path = /fake/lib;
      qualifier = "lib";
      flat = true;
    };
  };
  flatTests = listing: extra:
    forced (namesOf ({
        "/fake/lib" = {tests = "directory";};
        "/fake/lib/tests" = listing;
      }
      // extra)
    flatRoot);

  moduleRoot = {
    modules = {
      path = /fake/modules;
      qualifier = null;
    };
  };

  tree = {
    "/fake/modules" = {
      gradle = "directory";
      profiles = "directory";
    };
    "/fake/modules/gradle" = {
      "default.nix" = "regular";
      tests = "directory";
    };
    "/fake/modules/gradle/tests" = {
      "files.nix" = "regular";
      "_helpers.nix" = "regular";
      "fixture.json" = "regular";
    };
    "/fake/modules/profiles" = {
      tests = "directory";
      targets = "directory";
    };
    "/fake/modules/profiles/tests" = {
      "unit.nix" = "regular";
      "structure.nix" = "regular";
      "script.nix" = "regular";
    };
    "/fake/modules/profiles/targets" = {codex = "directory";};
    "/fake/modules/profiles/targets/codex" = {tests = "directory";};
    "/fake/modules/profiles/targets/codex/tests" = {"unit.nix" = "regular";};
  };
in {
  "test each kind file is named by its kind and its module, nested under the tested module above it" = {
    expr = lib.sort (a: b: a < b) (namesOf tree moduleRoot);
    expected = ["files:gradle" "script:profiles" "unit:profiles" "unit:profiles:codex" "unit:profiles:structure"];
  };
  "test a root outside modules/ qualifies its areas" = {
    expr = lib.sort (a: b: a < b) (namesOf tree {
      home = {
        path = /fake/modules;
        qualifier = "home";
      };
    });
    expected = ["files:home:gradle" "script:home:profiles" "unit:home:profiles" "unit:home:profiles:codex" "unit:home:profiles:structure"];
  };
  "test a flat root names each tests file as a unit area" = {
    expr =
      namesOf {
        "/fake/lib" = {tests = "directory";};
        "/fake/lib/tests" = {
          "frontmatter.nix" = "regular";
          "_fixtures.nix" = "regular";
        };
      } {
        lib = {
          path = /fake/lib;
          qualifier = "lib";
          flat = true;
        };
      };
    expected = ["unit:lib:frontmatter"];
  };
  "test a stray .nix file in a tests dir fails evaluation, naming it" = {
    expr = namesOf (tree // {"/fake/modules/gradle/tests" = {"checks.nix" = "regular";};}) moduleRoot;
    expectedError.type = "ThrownError";
    expectedError.msg = "/fake/modules/gradle/tests/checks\\.nix: a tests dir holds only";
  };
  "test a tests.nix beside a module fails evaluation" = {
    expr = namesOf (tree // {"/fake/modules/gradle" = {"tests.nix" = "regular";};}) moduleRoot;
    expectedError.type = "ThrownError";
    expectedError.msg = "/fake/modules/gradle/tests\\.nix: tests live in tests/<kind>\\.nix";
  };
  "test a symlink in a tests dir fails evaluation, naming it" = {
    expr = gradleTests {
      "files.nix" = "regular";
      "linked.nix" = "symlink";
    } {};
    expectedError.type = "ThrownError";
    expectedError.msg = "/fake/modules/gradle/tests/linked\\.nix: a tests dir holds no symlink";
  };
  "test a tests symlink beside a module fails evaluation" = {
    expr = forced (namesOf (tree // {"/fake/modules/gradle" = {tests = "symlink";};}) moduleRoot);
    expectedError.type = "ThrownError";
    expectedError.msg = "/fake/modules/gradle/tests: a tests dir must be a directory, not a symlink";
  };
  "test a .nix file in a subdirectory of a tests dir fails evaluation, naming it" = {
    expr = gradleTests {
      "files.nix" = "regular";
      nested = "directory";
    } {"/fake/modules/gradle/tests/nested" = {"unit.nix" = "regular";};};
    expectedError.type = "ThrownError";
    expectedError.msg = "/fake/modules/gradle/tests/nested/unit\\.nix: a subdirectory of a tests dir holds data only";
  };
  "test a symlink deep in a data dir of a tests dir fails evaluation" = {
    expr =
      gradleTests {
        "files.nix" = "regular";
        fixtures = "directory";
      } {
        "/fake/modules/gradle/tests/fixtures" = {deep = "directory";};
        "/fake/modules/gradle/tests/fixtures/deep" = {"SKILL.md" = "symlink";};
      };
    expectedError.type = "ThrownError";
    expectedError.msg = "/fake/modules/gradle/tests/fixtures/deep/SKILL\\.md: a tests dir holds no symlink";
  };
  "test a data dir without .nix files may sit in a tests dir" = {
    expr = lib.sort (a: b: a < b) (gradleTests {
        "files.nix" = "regular";
        fixtures = "directory";
      } {
        "/fake/modules/gradle/tests/fixtures" = {clean = "directory";};
        "/fake/modules/gradle/tests/fixtures/clean" = {"SKILL.md" = "regular";};
      });
    expected = ["files:gradle" "script:profiles" "unit:profiles" "unit:profiles:codex" "unit:profiles:structure"];
  };
  "test a tests dir holding only helpers and data fails evaluation, naming it" = {
    expr = gradleTests {
      "_helpers.nix" = "regular";
      "fixture.json" = "regular";
    } {};
    expectedError.type = "ThrownError";
    expectedError.msg = "/fake/modules/gradle/tests: a tests dir yields no suite";
  };
  "test a .nix file in a subdirectory of the flat lib tests root fails evaluation" = {
    expr = flatTests {
      "ai.nix" = "regular";
      helpers = "directory";
    } {"/fake/lib/tests/helpers" = {"shared.nix" = "regular";};};
    expectedError.type = "ThrownError";
    expectedError.msg = "/fake/lib/tests/helpers/shared\\.nix: a subdirectory of a tests dir holds data only";
  };
  "test a data dir in the flat lib tests root is allowed" = {
    expr = flatTests {
      "ai.nix" = "regular";
      fixtures = "directory";
    } {"/fake/lib/tests/fixtures" = {"SKILL.md" = "regular";};};
    expected = ["unit:lib:ai"];
  };
  "test a flat lib tests root holding only helpers fails evaluation" = {
    expr = flatTests {"_fixtures.nix" = "regular";} {};
    expectedError.type = "ThrownError";
    expectedError.msg = "/fake/lib/tests: a tests dir yields no suite";
  };
  "test nix-unit's test count descends into nested suites and counts only test attributes" = {
    expr = testCount {
      testA = {};
      area = {
        "test b" = {};
        helper = 1;
      };
      notes = "x";
    };
    expected = 2;
  };
  "test a unit suite with no test attribute fails evaluation, naming it" = {
    expr = withTests {
      name = "unit:empty";
      file = /fake/empty/tests/unit.nix;
    } {area.helper = {};};
    expectedError.type = "ThrownError";
    expectedError.msg = "/fake/empty/tests/unit\\.nix: unit:empty has no `test\\*` attribute";
  };
  "test two tests with one name fail evaluation, naming both files" = {
    expr = namesOf (tree
      // {
        "/fake/modules" = {
          gradle = "directory";
          other = "directory";
        };
        "/fake/modules/other" = {gradle = "directory";};
        "/fake/modules/other/gradle" = {tests = "directory";};
        "/fake/modules/other/gradle/tests" = {"files.nix" = "regular";};
      })
    moduleRoot;
    expectedError.type = "ThrownError";
    expectedError.msg = "two tests share a name: files:gradle";
  };
}
