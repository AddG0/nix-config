# The shared helpers.sh the scripts and justfile source.
{harness, ...}:
harness.bats "scripts-helpers" [./helpers.bats] {
  helpers = ../helpers.sh;
}
