# My ssh policy over the shared transport, through a fixture hostSpec: hostsAddr
# entries become reachable hosts, and every pinned key is materialized.
{
  harness,
  pkgs,
  lib,
  self,
  ...
}: let
  inherit (pkgs) openssh coreutils gnugrep;
  testLib = self.lib.extend (_: _: {inherit (self.inputs.home-manager.lib) hm;});
  hostSpec = {
    hostName = "test-host";
    hostPlatform = "x86_64-linux";
    primaryUsername = "tester";
    handle = "tester";
    home = "/home/tester";
    domain = "example.test";
    userFullName = "Test User";
    email.personal = "tester@example.test";
    githubEmail = "tester@example.test";
    networking = {
      ports.tcp.ssh = 2222;
      hostsAddr.testhost.ipv4 = "192.0.2.10";
    };
  };
  hm =
    (self.inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      lib = testLib;
      extraSpecialArgs = {inherit self hostSpec;};
      modules = [
        {
          config = {
            inherit hostSpec;
            home = {
              username = "tester";
              homeDirectory = "/home/tester";
              stateVersion = "24.05";
            };
          };
        }
        ../../../../../../modules/common/host-spec.nix
        ../../../../../common/core/ssh/default.nix
        ../default.nix
      ];
    }).config;

  # A pinned key is the only candidate ssh tries, so it has to be materialized.
  pinnedKeysMissing = let
    pinned = lib.filter (b: b.data.IdentitiesOnly or false) (lib.attrValues hm.programs.ssh.settings);
    files = lib.unique (map (lib.removePrefix "~/") (lib.concatMap (b: lib.toList (b.data.IdentityFile or [])) pinned));
  in
    lib.filter (k: !(hm.home.file ? ${k})) files;
in
  lib.throwIf (pinnedKeysMissing != [])
  "home/primary/common/core/ssh: pins ${lib.concatStringsSep ", " pinnedKeysMissing} but never materializes it"
  (harness.bats "primary-ssh-routing" [./routing.bats] {
    nativeBuildInputs = [coreutils openssh gnugrep];
    sshConfig = pkgs.writeText "ssh-config" hm.home.file.".ssh/config".text;
    host = "testhost";
    hostAddr = hostSpec.networking.hostsAddr.testhost.ipv4;
    sshPort = toString hostSpec.networking.ports.tcp.ssh;
  })
