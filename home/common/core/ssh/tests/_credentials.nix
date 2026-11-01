# The rendered ssh config's routing, over a fixture hostSpec: hostsAddr entries
# become reachable hosts, and the 1Password agent steps aside for the tmux link.
{
  harness,
  pkgs,
  lib,
  self,
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
  evalHome = modules:
    (self.inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      lib = testLib;
      extraSpecialArgs = {inherit self hostSpec;};
      modules =
        [
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
          ../../../../../modules/common/host-spec.nix
          ../default.nix
          ../../../../primary/common/core/ssh.nix
        ]
        ++ modules;
    }).config;
  homes = {
    standard = evalHome [];
    onePassword = evalHome [../../../../primary/common/optional/secrets/onepassword-ssh.nix];
  };

  hmFor = name: homes.${name};

  # A pinned key is the only candidate ssh tries, so it has to be materialized.
  keysMaterialized = name: let
    blocks = lib.attrValues (hmFor name).programs.ssh.settings;
    pinned = lib.filter (b: b.data.IdentitiesOnly or false) blocks;
    files = lib.unique (map (lib.removePrefix "~/") (lib.concatMap (b: lib.toList (b.data.IdentityFile or [])) pinned));
    missing = lib.filter (k: !((hmFor name).home.file ? ${k})) files;
  in
    lib.throwIf (missing != [])
    "ssh/tests/_credentials.nix: ${name} pins ${lib.concatStringsSep ", " missing} but never materializes it";

  onePasswordAgent = lib.removePrefix "\"" (lib.removeSuffix "\"" (hmFor "onePassword").programs.ssh.settings."1password-agent".data.IdentityAgent);

  routing = keysMaterialized "standard" (keysMaterialized "onePassword"
    (harness.bats "ssh-routing" [./routing.bats] {
      nativeBuildInputs = [coreutils openssh gnugrep];
      sshConfig = pkgs.writeText "ssh-config" (hmFor "standard").home.file.".ssh/config".text;
      onePasswordSshConfig = pkgs.writeText "ssh-config-onepassword" (hmFor "onePassword").home.file.".ssh/config".text;
      inherit onePasswordAgent;
      host = "testhost";
      hostAddr = hostSpec.networking.hostsAddr.testhost.ipv4;
      sshPort = toString hostSpec.networking.ports.tcp.ssh;
    }));

  # Apps outside a shell (t3code) get their agent from this, not the zsh hook.
  sessionAgent = harness.check "ssh-default-agent" (harness.values {
    "test apps outside a shell follow the tmux-attached client's agent" = {
      expr = (hmFor "standard").programs.ssh.defaultAgent;
      expected = "/home/tester/.ssh/ssh_auth_sock";
    };
    "test apps outside a shell keep the tmux link when 1Password serves the keys" = {
      expr = (hmFor "onePassword").programs.ssh.defaultAgent;
      expected = "/home/tester/.ssh/ssh_auth_sock";
    };
  });
in {
  inherit routing sessionAgent onePasswordAgent;
  onePasswordZshrc = pkgs.writeText "zshrc-onepassword" (hmFor "onePassword").programs.zsh.initContent;
}
