# Regression suite for the stale-session sweep. Every case here is a bug that
# shipped: the timer could not reach the tmux server, ssh's client-attached hook
# overwrote this module's, continuum's fresh session_created restarted the
# countdown each boot, and a name with spaces lost all but its first word.
# ./prune.bats covers the sweep, ./hooks.bats the hooks against a live tmux.
{
  harness,
  pkgs,
  self,
  ...
}: let
  inherit (pkgs) coreutils tmux util-linux gnugrep ncurses;
  testLib = self.lib.extend (_: _: {inherit (self.inputs.home-manager.lib) hm;});
  tmuxConfig =
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
        ../default.nix
        ../../../../ssh/default.nix
      ];
    }).config;

  recordAttach = pkgs.callPackage ../record-attach.nix {};
  prune = pkgs.callPackage ../prune.nix {};
in
  harness.bats "tmux-stale-sessions" [./prune.bats ./hooks.bats] {
    nativeBuildInputs = [coreutils tmux util-linux gnugrep ncurses];
    prune = "${prune}/bin/tmux-prune-stale-sessions";
    recordAttach = "${recordAttach}/bin/tmux-record-session-attach";
    hostConf = pkgs.writeText "tmux.conf" tmuxConfig.programs.tmux.extraConfig;
    bash = "${pkgs.bash}/bin/bash";
    # Each .bats file reaches the store alone, so a relative load would miss it.
    common = "${./_common.bash}";
  }
