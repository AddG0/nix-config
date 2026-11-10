# The REAL private-inputs.sh against the nix stub in ./script.nix: FAKE_DEBUG_LOG is what the host's eval logged.

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert

  export OUT=$BATS_TEST_TMPDIR FAKE_EVAL_EXIT=0
  export FAKE_DEBUG_LOG="evaluating file '/nix/store/a-source/flake.nix'
using input 'git+ssh://git@example.com/o/b.git?ref=main&rev=1111' in '/nix/store/b-source'
using input 'github:o/public/2222' in '/nix/store/p-source'
using input 'git+ssh://git@example.com/o/a.git?rev=3333' in '/nix/store/a-source'
using input 'git+ssh://git@example.com/o/b.git?rev=4444' in '/nix/store/b2-source'
"
}

@test "lists each repo the build fetches over SSH once, without the public ones" {
  run bash "$privateInputs" rig
  assert_success
  assert_output "rig's build fetches these repos over SSH:
  ssh://git@example.com/o/a.git
  ssh://git@example.com/o/b.git"
}

@test "evaluates the named host's system from this checkout" {
  run bash "$privateInputs" rig
  assert_success
  assert_equal "$(cat "$OUT/nix-args")" "eval --debug --raw ${privateInputs%/scripts/*}#nixosConfigurations.rig.config.system.build.toplevel.drvPath"
}

@test "says so when the build fetches nothing over SSH" {
  FAKE_DEBUG_LOG="using input 'github:o/public/2222' in '/nix/store/p-source'" run bash "$privateInputs" rig
  assert_success
  assert_output "rig's build fetches nothing over SSH."
}

@test "fails when the eval logs no inputs, rather than reporting nothing private" {
  FAKE_DEBUG_LOG="evaluating file '/nix/store/x'" run bash "$privateInputs" rig
  assert_failure 1
  assert_output --partial 'Nix logged no "using input" line while evaluating rig'
}

@test "fails with nix's error when the host does not evaluate" {
  FAKE_EVAL_EXIT=1 FAKE_DEBUG_LOG="evaluating file '/nix/store/x'
error: flake does not provide attribute 'nixosConfigurations.nope'
       Did you mean rig?" run bash "$privateInputs" nope
  assert_failure 1
  assert_output "Evaluating nope's system failed:
error: flake does not provide attribute 'nixosConfigurations.nope'
       Did you mean rig?"
}

@test "shows git's reason when a fetch fails" {
  FAKE_EVAL_EXIT=1 FAKE_DEBUG_LOG="evaluating file '/nix/store/x'
git@example.com: Permission denied (publickey).
fatal: Could not read from remote repository.
error: Failed to fetch git repository 'ssh://git@example.com/o/a.git'" run bash "$privateInputs" rig
  assert_failure 1
  assert_output "Evaluating rig's system failed:
fatal: Could not read from remote repository.
git@example.com: Permission denied (publickey).
error: Failed to fetch git repository 'ssh://git@example.com/o/a.git'"
}

@test "shows the end of the log when nix fails without an error block" {
  FAKE_EVAL_EXIT=127 FAKE_DEBUG_LOG="nix: command not found" run bash "$privateInputs" rig
  assert_failure 1
  assert_output "Evaluating rig's system failed:
nix: command not found"
}
