# Fleet-wide remote builder registry, read by nixos/darwin nix-builders.builder and nixos nix-builders.client.
let
  linuxFeatures = ["big-parallel" "kvm" "nixos-test" "benchmark"];
in {
  # Key the builder user accepts; its private half is the nix-builder-key sops secret.
  publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPolgQKCN05Js3NXyBQGs4ii6tTmHYV2jRt79ZCdbMX5";

  # Every host here must import nix-builders.builder; hostKey is its sshd ed25519 key.
  builders = {
    loki = {
      system = "x86_64-linux";
      maxJobs = 20;
      speedFactor = 100;
      supportedFeatures = linuxFeatures;
      hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOoqypWaPrUfWk8uUATK/mVM1uMzDVJW5HlNuXRMBFAz";
    };
    odin = {
      system = "x86_64-linux";
      maxJobs = 20;
      speedFactor = 100;
      supportedFeatures = linuxFeatures;
      hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOZoUzRGlGQDkKc2PkWhANu2EQ75v8J7qGL09L+UXR/U";
    };
    thor = {
      system = "x86_64-linux";
      maxJobs = 20;
      speedFactor = 100;
      supportedFeatures = linuxFeatures;
      hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII7vXKiuhyOa2+fiSVruvgZrkHNQMwKHkbkSF4rLRbcR";
    };
    # M4 Max, 16 cores. Darwin can't offer kvm/nixos-test.
    ghost = {
      system = "aarch64-darwin";
      maxJobs = 16;
      speedFactor = 100;
      supportedFeatures = ["big-parallel" "benchmark"];
      hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBYMtWlTHq7q73dw/0VNr7dDv8Rw5M3s4xW3oAdElXIO";
    };
  };
}
