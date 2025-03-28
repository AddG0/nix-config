{inputs, ...}:
# so `args` can be passed in
final: prev: {
  pterodactyl-wings = prev.nur.repos.xddxdd.pterodactyl-wings.overrideAttrs (old: {
    doCheck = false; # Disable broken Go tests
  });
}
