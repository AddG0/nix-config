# Boots every distinct VS Code profile a host deploys and fails when VS Code or an extension rewrites a managed user file.
{
  pkgs,
  lib,
  self,
  ...
}: let
  inherit (pkgs.stdenv.hostPlatform) system;

  isUserFile = target: lib.hasPrefix ".config/Code/User/" target;
  isDeployed = file: file.enable && (isUserFile file.target || lib.hasPrefix ".vscode/extensions/" file.target);

  profileOf = host: user: hm: {
    name = lib.replaceStrings ["-"] ["_"] "${host}_${user}";
    inherit (hm.home) username homeDirectory;
    inherit (hm.programs.vscode) package;
    files = map (file: {inherit (file) target source;}) (lib.filter isDeployed (lib.attrValues hm.home.file));
  };

  deployed = lib.concatLists (lib.mapAttrsToList (host: nixos:
    lib.optionals (nixos.pkgs.stdenv.hostPlatform.system == system) (lib.concatLists (lib.mapAttrsToList (user: hm:
      lib.optional hm.programs.vscode.enable (profileOf host user hm))
    nixos.config.home-manager.users or {})))
  self.nixosConfigurations);

  # Hosts that deploy the same package and files boot once, under the first host's name.
  sameDeployment = profile: builtins.unsafeDiscardStringContext (builtins.toJSON {inherit (profile) package files;});
  profiles = map lib.head (lib.attrValues (lib.groupBy sameDeployment deployed));

  ancestors = target: let
    parts = lib.init (lib.splitString "/" target);
  in
    lib.genList (n: lib.concatStringsSep "/" (lib.take (n + 1) parts)) (lib.length parts);

  # User-owned parents, so VS Code can write beside the links as it does on a host.
  homeRules = profile: let
    path = target: "${profile.homeDirectory}/${target}";
  in
    map (dir: "d ${path dir} 0755 ${profile.username} users -") (lib.unique (lib.concatMap (file: ancestors file.target) profile.files))
    ++ map (file: "L+ ${path file.target} - - - - ${file.source}") profile.files;

  node = profile: {
    virtualisation = {
      memorySize = 4096;
      cores = 2;
      diskSize = 4096;
    };
    users.users.${profile.username} = {
      isNormalUser = true;
      home = profile.homeDirectory;
    };
    environment.systemPackages = [profile.package pkgs.xvfb-run pkgs.diffutils];
    systemd.tmpfiles.rules = homeRules profile;
  };

  scriptProfiles =
    map (profile: {
      inherit (profile) name username homeDirectory;
      userFiles = map (file: file.target) (lib.filter (file: isUserFile file.target) profile.files);
    })
    profiles;
in
  pkgs.testers.runNixOSTest {
    name = "vscode-user-files-stay-unwritten";
    nodes = lib.listToAttrs (map (profile: lib.nameValuePair profile.name (node profile)) profiles);
    testScript = ''
      import json
      import time

      profiles = json.loads(${builtins.toJSON (builtins.toJSON scriptProfiles)})
      startup_timeout = 600
      # onStartupFinished extensions (Postman among them) write within seconds of activating.
      settle_seconds = 45


      # A writable copy records any write VS Code makes; on a host the same write hits the store link and fails.
      def make_writable(machine, profile):
          home = profile["homeDirectory"]
          for target in profile["userFiles"]:
              path = f"{home}/{target}"
              machine.succeed(f"cp \"$(readlink -f {path})\" {path}.generated")
              machine.succeed(f"install -m 0644 -o {profile['username']} -g users {path}.generated {path}")


      def wait_for_startup(machine, profile):
          started = f"grep -rqs onStartupFinished {profile['homeDirectory']}/.config/Code/logs/*/window*/exthost/exthost.log"
          deadline = time.monotonic() + startup_timeout
          while machine.execute(started)[0] != 0:
              if machine.execute("systemctl is-active -q vscode")[0] != 0:
                  raise Exception(f"{profile['name']}: VS Code exited before extensions started:\n" + machine.execute("journalctl -u vscode --no-pager")[1])
              if time.monotonic() > deadline:
                  raise Exception(f"{profile['name']}: no onStartupFinished activation within {startup_timeout}s:\n" + machine.execute("journalctl -u vscode --no-pager")[1])
              time.sleep(2)


      def run_vscode(machine, profile):
          home = profile["homeDirectory"]
          machine.succeed(
              f"systemd-run --collect --unit=vscode --uid={profile['username']} --gid=users"
              # systemd-run's default PATH lacks the system profile, and VS Code's launcher needs `sh` from it.
              f" --setenv=HOME={home} --setenv=PATH=/run/wrappers/bin:/run/current-system/sw/bin -p WorkingDirectory={home}"
              " xvfb-run -a code --wait --disable-gpu --verbose"
          )
          wait_for_startup(machine, profile)
          machine.sleep(settle_seconds)
          machine.succeed("systemctl stop vscode")


      def rewrites(machine, profile):
          home = profile["homeDirectory"]
          diffs = [machine.execute(f"diff -u {home}/{target}.generated {home}/{target}")[1] for target in profile["userFiles"]]
          return "\n".join(diff for diff in diffs if diff)


      failures = []
      for profile in profiles:
          machine = next(m for m in machines if m.name == profile["name"])
          machine.start()
          machine.wait_for_unit("multi-user.target")
          make_writable(machine, profile)
          run_vscode(machine, profile)
          changed = rewrites(machine, profile)
          if changed:
              failures.append(f"{profile['name']}: VS Code rewrote managed files (generated -> written):\n{changed}")
          machine.shutdown()

      if failures:
          raise Exception("\n\n".join(failures))
    '';
  }
