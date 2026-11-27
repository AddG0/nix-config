# x3d-cache-ccd against fixture sysfs CPU trees: each CPU's L3 size and, optionally, its online flag.

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert

  cpus=$BATS_TEST_TMPDIR/cpu
}

# cpu <n> <l3 size> [online]
cpu() {
  mkdir -p "$cpus/cpu$1/cache/index3"
  echo "$2" >"$cpus/cpu$1/cache/index3/size"
  [ -z "${3:-}" ] || echo "$3" >"$cpus/cpu$1/online"
}

@test "splits an X3D layout into the V-Cache CPUs and the rest" {
  for n in 0 1 4 5; do cpu "$n" 98304K; done
  for n in 2 3 6 7; do cpu "$n" 32768K; done

  run "$cacheCcd" "$cpus"

  assert_success
  assert_output "0-1,4-5 2-3,6-7"
}

@test "orders CPUs numerically past cpu9" {
  for n in 0 1 10 11; do cpu "$n" 98304K; done
  for n in 2 3 12 13; do cpu "$n" 32768K; done

  run "$cacheCcd" "$cpus"

  assert_success
  assert_output "0-1,10-11 2-3,12-13"
}

@test "leaves offline CPUs out of both sets" {
  cpu 0 98304K
  cpu 1 98304K 1
  cpu 2 32768K
  cpu 3 32768K 0

  run "$cacheCcd" "$cpus"

  assert_success
  assert_output "0-1 2"
}

@test "exits 3 when every CPU shares one L3 size" {
  for n in 0 1 2 3; do cpu "$n" 32768K; done

  run "$cacheCcd" "$cpus"

  assert_failure 3
  assert_output --partial "same L3 cache"
}

@test "fails naming the directory when no CPU reports an L3 size" {
  mkdir -p "$cpus/cpu0"

  run "$cacheCcd" "$cpus"

  assert_failure 1
  assert_output --partial "$cpus"
}

@test "fails naming the CPU when its L3 size is not in kilobytes" {
  cpu 0 98304K
  cpu 1 96M

  run "$cacheCcd" "$cpus"

  assert_failure 1
  assert_output --partial "cpu1 reports an L3 size of '96M'"
}
