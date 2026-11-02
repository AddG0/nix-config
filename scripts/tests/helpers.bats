# The REAL helpers.sh, sourced as the scripts and justfile do.

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert
  source "$helpers"
}

@test "format_duration shows seconds alone under a minute" {
  run format_duration 42
  assert_output "42s"
}

@test "format_duration shows minutes and seconds under an hour" {
  run format_duration 3589
  assert_output "59m 49s"
}

@test "format_duration keeps zero seconds once minutes show" {
  run format_duration 60
  assert_output "1m 0s"
}

@test "format_duration shows hours, minutes and seconds from an hour up" {
  run format_duration 3725
  assert_output "1h 2m 5s"
}

@test "format_duration keeps zero minutes and seconds once hours show" {
  run format_duration 3600
  assert_output "1h 0m 0s"
}
