# Which agent ssh and a fresh shell use once 1Password serves the keys, over the shared ssh transport.
{
  harness,
  pkgs,
  lib,
  self,
  ...
}: let
  inherit (pkgs) openssh coreutils gnugrep gawk zsh;
  testLib = self.lib.extend (_: _: {inherit (self.inputs.home-manager.lib) hm;});
  hm =
    (self.inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      lib = testLib;
      extraSpecialArgs = {
        inherit self;
        hostSpec = {
          primaryUsername = "tester";
          home = "/home/tester";
          system.stateVersion = "24.05";
        };
      };
      modules = [
        {
          home = {
            username = "tester";
            homeDirectory = "/home/tester";
            stateVersion = "24.05";
          };
        }
        ../../../../../../common/core/ssh/default.nix
        ../default.nix
      ];
    }).config;

  onePasswordAgent = lib.removePrefix "\"" (lib.removeSuffix "\"" hm.programs.ssh.settings."1password-agent".data.IdentityAgent);

  # Apps outside a shell (t3code) get their agent from this, not the zsh hook.
  sessionAgent = harness.check "onepassword-ssh-default-agent" (harness.values {
    "test apps outside a shell keep the tmux link when 1Password serves the keys" = {
      expr = hm.programs.ssh.defaultAgent;
      expected = "/home/tester/.ssh/ssh_auth_sock";
    };
  });
in
  harness.bats "onepassword-ssh-tests" [./routing.bats ./zshrc.bats] {
    nativeBuildInputs = [coreutils openssh gnugrep gawk zsh];
    sshConfig = pkgs.writeText "ssh-config-onepassword" hm.home.file.".ssh/config".text;
    zshrc = pkgs.writeText "zshrc-onepassword" hm.programs.zsh.initContent;
    inherit onePasswordAgent sessionAgent;
    host = "example.test";
  }
