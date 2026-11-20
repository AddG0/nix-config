# Boots the deployed tmux units and config, and fails when the server dies with the scope that ran `tmux` first or its config deletes the units.
{
  pkgs,
  lib,
  self,
  ...
}: let
  inherit (pkgs.stdenv.hostPlatform) system;

  deployedHomes = lib.concatLists (lib.mapAttrsToList (_: nixos:
    lib.optionals (nixos.pkgs.stdenv.hostPlatform.system == system) (lib.concatLists (lib.mapAttrsToList (_: hm:
      lib.optional (hm.xdg.configFile ? "systemd/user/tmux-server.socket") {
        socket = hm.xdg.configFile."systemd/user/tmux-server.socket".source;
        service = hm.xdg.configFile."systemd/user/tmux-server.service".source;
        tmuxConf = hm.xdg.configFile."tmux/tmux.conf".source;
        tmuxTmpdir = hm.home.sessionVariables.TMUX_TMPDIR;
      })
    nixos.config.home-manager.users or {})))
  self.nixosConfigurations);

  home = lib.head deployedHomes;
in
  assert lib.assertMsg (deployedHomes != []) "no host deploys home-manager's tmux-server.socket";
    pkgs.testers.runNixOSTest {
      name = "tmux-server-outlives-its-starter";
      nodes.machine = {
        users.users.alice = {
          isNormalUser = true;
          uid = 1000;
          linger = true;
        };
        environment.systemPackages = [pkgs.tmux];
        system.extraDependencies = [home.socket home.service home.tmuxConf];
      };
      testScript = ''
        import shlex

        # The login shell's TMUX_TMPDIR, so clients look for the socket where a real shell would.
        tmux_tmpdir = ${builtins.toJSON home.tmuxTmpdir}
        units = "/home/alice/.config/systemd/user"


        def as_alice(cmd):
            env = f"export HOME=/home/alice XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus; export TMUX_TMPDIR={tmux_tmpdir}"
            return f"runuser -u alice -- sh -c {shlex.quote(env + '; ' + cmd)}"


        machine.wait_for_unit("user@1000.service")
        # Linked into ~/.config as home-manager does, since `systemctl disable` deletes only links there.
        machine.succeed(as_alice(" && ".join([
            f"mkdir -p {units} /home/alice/.config/tmux",
            f"ln -s ${home.socket} {units}/tmux-server.socket",
            f"ln -s ${home.service} {units}/tmux-server.service",
            "ln -s ${home.tmuxConf} /home/alice/.config/tmux/tmux.conf",
            "systemctl --user daemon-reload",
            "systemctl --user start tmux-server.socket",
        ])))

        # The client starting the first session runs in a scope, as an agent's shell does under T3 Code.
        machine.succeed(as_alice("systemd-run --user --scope --unit=starter tmux new-session -d -s probe sleep infinity"))
        server_pid = machine.succeed(as_alice("tmux display-message -p -t probe '#{pid}'")).strip()
        cgroup = machine.succeed(f"cat /proc/{server_pid}/cgroup")
        assert "/tmux-server.service" in cgroup, f"tmux server {server_pid} is not in tmux-server.service: {cgroup}"

        machine.fail(as_alice("systemctl --user is-active starter.scope"))
        machine.succeed(as_alice("tmux has-session -t probe"))

        status, _ = machine.execute(f"test -L {units}/tmux-server.service")
        assert status == 0, f"loading tmux.conf deleted {units}/tmux-server.service, so the next server start fails"
      '';
    }
