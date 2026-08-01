# Tests for the two-tier resourcesRoot check: source dirs are rejected during
# evaluation, derivation roots when the skill dir is assembled.
#
# Auto-discovered and wired into `nix flake check` by checks/module-tests.nix.
{
  pkgs,
  lib,
  ...
}: let
  skillResources = import ./skill-resources.nix {inherit lib;};
  validation = import ./validation.nix {inherit lib;};

  derivationRootWithSkillMd = pkgs.linkFarm "reserved-resources" [
    {
      name = "SKILL.md";
      path = ./test-fixtures/reserved/SKILL.md;
    }
  ];

  failures = root:
    map (a: a.message)
    (lib.filter (a: !a.assertion) (validation.validateSharedConfig "profile 'p'" {
      skills.demo = {
        prompt = {
          text = "body";
          source = null;
        };
        resourcesRoot = root;
      };
    }));

  expect = label: actual: expected:
    lib.optionalString (actual != expected) ''
      echo "FAIL ${label}: expected ${lib.generators.toPretty {} expected}, got ${lib.generators.toPretty {} actual}" >&2
      exit 1
    '';

  guard = skillResources.rejectReserved "codex" "demo";
in
  pkgs.runCommand "code-assistant-profiles-test" {} ''
    ${expect "source dir with SKILL.md is rejected at eval" (failures ./test-fixtures/reserved) [
      "profile 'p' skill 'demo' resourcesRoot must not contain SKILL.md; SKILL.md is generated from skill metadata and prompt"
    ]}
    ${expect "clean source dir passes eval" (failures ./test-fixtures/clean) []}
    ${expect "derivation root is not probed at eval" (failures derivationRootWithSkillMd) []}
    ${expect "source dir is inspectable" (skillResources.inspectableAtEval ./test-fixtures/clean) true}
    ${expect "derivation is not inspectable" (skillResources.inspectableAtEval derivationRootWithSkillMd) false}

    # --- build-time guard: same rule, enforced against the assembled dir ---
    mkdir -p reserved && touch reserved/SKILL.md
    if ( out="$PWD/reserved"; ${guard} ) 2>reserved.err; then
      echo "FAIL guard: accepted a resourcesRoot containing SKILL.md" >&2
      exit 1
    fi
    grep -q "codex skill 'demo' resourcesRoot must not contain SKILL.md" reserved.err || {
      echo "FAIL guard: wrong rejection message" >&2
      cat reserved.err >&2
      exit 1
    }

    mkdir -p clean && touch clean/reference.md
    if ! ( out="$PWD/clean"; ${guard} ) 2>clean.err; then
      echo "FAIL guard: rejected a clean resourcesRoot" >&2
      cat clean.err >&2
      exit 1
    fi

    echo "code-assistant-profiles: resourcesRoot eval + build checks OK"
    touch "$out"
  ''
