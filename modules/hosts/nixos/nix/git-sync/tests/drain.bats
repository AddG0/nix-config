# git-sync's Kubernetes node "t" across a reboot, against a kubectl logging to $KUBECTL_LOG: drained before, never holding it up, uncordoned after.

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert

  export STATE_DIRECTORY=$BATS_TEST_TMPDIR/state
  mkdir -p "$STATE_DIRECTORY"
  export KUBECTL_LOG=$BATS_TEST_TMPDIR/kubectl.log
  : >"$KUBECTL_LOG"
  export UNCORDON_RETRY_SECONDS=0
}

kubectl_calls() {
  cut -d' ' -f1 "$KUBECTL_LOG" | paste -sd' '
}

@test "drains the node before the reboot and uncordons it after the boot" {
  run $beforeReboot
  assert_success
  assert_equal "$(kubectl_calls)" "get drain"
  assert_equal "$(sed -n 2p "$KUBECTL_LOG")" "drain t --ignore-daemonsets --delete-emptydir-data --force"

  run "$node" uncordon
  assert_success
  assert_equal "$(kubectl_calls)" "get drain uncordon"
  assert [ ! -e "$STATE_DIRECTORY/cordoned-node" ]
}

@test "still lets the reboot go ahead when the drain fails, naming the failure, and uncordons after the boot" {
  KUBECTL_DRAIN_EXIT=1 run $beforeReboot
  assert_success
  assert_output --partial "Draining t failed or timed out (exit 1); rebooting anyway."

  run "$node" uncordon
  assert_success
  assert_equal "$(kubectl_calls)" "get drain uncordon"
}

@test "gives up a drain that outlasts its limit and lets the reboot go ahead" {
  SECONDS=0
  KUBECTL_DRAIN_HANGS=1 DRAIN_SECONDS=1 run $beforeReboot
  assert_success
  assert_output --partial "Draining t failed or timed out (exit 124); rebooting anyway."
  assert [ "$SECONDS" -lt 10 ]
}

@test "reboots without draining a node it cannot read" {
  KUBECTL_GET_EXIT=1 run $beforeReboot
  assert_success
  assert_output --partial "Cannot read Kubernetes node t; rebooting without draining it."
  assert_equal "$(kubectl_calls)" "get"
}

@test "leaves a node a person had cordoned cordoned after the boot" {
  NODE_UNSCHEDULABLE=true run $beforeReboot
  assert_success
  assert_equal "$(kubectl_calls)" "get drain"

  run "$node" uncordon
  assert_success
  assert_output "git-sync cordoned no node before this boot; nothing to uncordon."
  assert_equal "$(kubectl_calls)" "get drain"
}

@test "keeps trying to uncordon until the API server answers after the boot" {
  echo t >"$STATE_DIRECTORY/cordoned-node"
  UNCORDON_FAILURES=2 run "$node" uncordon
  assert_success
  assert_equal "$(kubectl_calls)" "uncordon uncordon uncordon"
  assert [ ! -e "$STATE_DIRECTORY/cordoned-node" ]
}

@test "fails, naming the node and how to retry, when the API server never answers, keeping the cordon on record" {
  echo t >"$STATE_DIRECTORY/cordoned-node"
  UNCORDON_FAILURES=1000 run "$node" uncordon
  assert_failure
  assert_output --partial "Could not uncordon Kubernetes node t; it stays cordoned until 'systemctl start nix-remote-rebuild-uncordon' succeeds."
  assert [ -e "$STATE_DIRECTORY/cordoned-node" ]
}
