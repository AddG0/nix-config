# Two guards over the rendered ssh config: what it resolves to, and what a real
# server is offered. Grant, deny and forge preference live in three different
# modules, so a mismatch between them only appears once rendered.
{
  pkgs,
  lib,
  self,
}: let
  inherit (pkgs) runCommand openssh coreutils gnugrep gawk;
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
      ports.tcp.ssh = 22;
      hostsAddr.testhost.ipv4 = "127.0.0.1";
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
          ../../../../modules/common/host-spec.nix
          ./default.nix
          ../../../primary/common/core/ssh.nix
        ]
        ++ modules;
    }).config;
  homes = {
    standard = evalHome [];
    onePassword = evalHome [../../../primary/common/optional/secrets/1password-ssh.nix];
  };

  hmFor = name: homes.${name};

  usable = name:
    ((hmFor name).home.file ? ".ssh/config")
    && hostSpec.networking.hostsAddr != {};
  hasAgentBlock = name: (hmFor name).programs.ssh.settings ? "1password-agent";

  names = builtins.filter usable (lib.naturalSort (builtins.attrNames homes));
  # An IdentityAgent block is a `Match host *` that outranks `Host *`, so cover a
  # host that has one and a host that does not.
  withAgentBlock = lib.findFirst hasAgentBlock null names;
  withoutAgentBlock = lib.findFirst (n: !hasAgentBlock n) null names;

  # Every key the config names has to be one the config also materializes, or
  # the preference silently resolves to nothing.
  # An unpinned name is a preference ssh skips when the file is absent; a
  # pinned one is the only candidate there is, so it has to exist.
  pinnedKeys = name: let
    blocks = lib.attrValues (hmFor name).programs.ssh.settings;
    pinned = lib.filter (b: b.data.IdentitiesOnly or false) blocks;
    files = lib.concatMap (b: lib.toList (b.data.IdentityFile or [])) pinned;
  in
    lib.unique (map (lib.removePrefix "~/") files);

  keysMaterialized = name: let
    missing = lib.filter (k: !((hmFor name).home.file ? ${k})) (pinnedKeys name);
  in
    lib.throwIf (missing != [])
    "ssh/credential-tests.nix: ${name} pins ${lib.concatStringsSep ", " missing} but never materializes it";

  sshConfigOf = name: pkgs.writeText "ssh-config-${name}" (hmFor name).home.file.".ssh/config".text;
  grantedHost = name:
    lib.head (lib.naturalSort
      (lib.attrNames hostSpec.networking.hostsAddr));

  # ssh expands ~ from getpwuid, not $HOME, so a config placed under $HOME is
  # silently never read in a sandbox; -F names it instead.
  preamble = ''
    cfg=$PWD/ssh_config
    install -m600 "$sshConfig" "$cfg"
    pwhome=$(${gawk}/bin/awk -F: -v u="$(id -u)" '$3==u {print $6}' /etc/passwd | head -1)
    : "''${pwhome:=$PWD}"
    mkdir -p "$pwhome/.ssh"
  '';

  resolution = name:
    keysMaterialized name
    (runCommand "ssh-policy-resolves-${name}" {
        nativeBuildInputs = [coreutils openssh gnugrep gawk];
        sshConfig = sshConfigOf name;
        granted = grantedHost name;
      } ''
        ${preamble}
        fail() { echo "FAIL [${name}]: $1"; exit 1; }
        opt() { ssh -F "$cfg" -G "$2" | grep -i "^$1 " | cut -d' ' -f2-; }

        echo "--- [${name}] every host is named my identity and nothing else"
        [ "$(opt identityfile unlisted.invalid)" = '~/.ssh/primary.pub' ] ||
          fail "an unknown host is named $(opt identityfile unlisted.invalid), not just primary"
        [ "$(opt identitiesonly unlisted.invalid)" = no ] ||
          fail "the list is closed after primary, so the agent's other keys never follow"

        echo "--- [${name}] an unlisted host gets no agent and keeps its prompts"
        [ "$(opt forwardagent unlisted.invalid)" = no ] ||
          fail "an unlisted host would get a forwarded agent"
        [ "$(opt passwordauthentication unlisted.invalid)" = yes ] ||
          fail "a host that takes none of my keys lost its password prompt"
        [ "$(opt kbdinteractiveauthentication unlisted.invalid)" = yes ] ||
          fail "a host that takes none of my keys lost keyboard-interactive"

        echo "--- [${name}] one of my own hosts forwards the agent on"
        [ "$(opt forwardagent "$granted")" = yes ] ||
          fail "$granted lost agent forwarding"
        [ "$(opt identityfile "$granted" | head -1)" = '~/.ssh/primary.pub' ] ||
          fail "$granted does not inherit the identity order"

        echo "--- [${name}] a forge inherits that same order rather than pinning"
        [ "$(opt identityfile github.com | head -1)" = '~/.ssh/primary.pub' ] ||
          fail "github.com leads with $(opt identityfile github.com | head -1), not primary"
        [ "$(opt identitiesonly github.com)" = no ] ||
          fail "github.com is pinned, so it cannot fall back to my other keys"

        echo "--- [${name}] a key passed with -i is tried ahead of the order"
        : >"$PWD/adhoc.pub"
        [ "$(ssh -F "$cfg" -G -i "$PWD/adhoc.pub" unlisted.invalid |
            grep -i '^identityfile ' | head -1 | cut -d' ' -f2-)" = "$PWD/adhoc.pub" ] ||
          fail "a key passed with -i did not take precedence"

        touch $out
      '');

  # Resolution says what ssh intends; only a server says what goes on the wire.
  # The sandbox user's shell does not exist so sshd accepts nobody — but an
  # unknown user still gets the full offer exchange, the half carrying policy.
  wireOffers = name:
    runCommand "ssh-policy-offers-${name}" {
      nativeBuildInputs = [coreutils openssh gnugrep gawk];
      sshConfig = sshConfigOf name;
      granted = grantedHost name;
    } ''
            ${preamble}
            log=$PWD/sshd.log
            fail() {
              echo "FAIL [${name}]: $1"
              echo "--- last 20 lines of sshd log ---"
              tail -20 "$log" || true
              exit 1
            }
            # ssh-agent's socket goes under $HOME, which the sandbox aims at a missing dir.
            export HOME=$PWD/home
            mkdir -p "$HOME/.ssh"
            port=22022

            for k in primary spare; do
              ssh-keygen -q -t ed25519 -N "" -C "$k" -f "$PWD/$k"
            done
            cp "$PWD/primary.pub" "$pwhome/.ssh/primary.pub"
            ssh-keygen -q -t ed25519 -N "" -f "$PWD/host_key"
            fp() { ssh-keygen -lf "$1" | awk '{print $2}'; }

      cat >"$PWD/sshd_config" <<EOF
      Port $port
      ListenAddress 127.0.0.1
      HostKey $PWD/host_key
      AuthorizedKeysFile /dev/null
      StrictModes no
      UsePAM no
      PasswordAuthentication no
      KbdInteractiveAuthentication no
      # Repeated unknown-user attempts are the point here; without this every
      # case after the first is throttled rather than answered.
      PerSourcePenalties no
      PidFile $PWD/sshd.pid
      LogLevel VERBOSE
      EOF

            ${openssh}/bin/sshd -D -f "$PWD/sshd_config" -E "$log" &
            trap 'kill %1 2>/dev/null' EXIT
            for _ in $(seq 100); do
              grep -q "Server listening" "$log" 2>/dev/null && break
              sleep 0.1
            done
            grep -q "Server listening" "$log" || fail "sshd never came up"

            eval "$(ssh-agent -s)" >/dev/null
            [ -n "''${SSH_AUTH_SOCK:-}" ] || fail "ssh-agent did not start"
            load() {
              ssh-add -D >/dev/null 2>&1 || true
              for k in "$@"; do
                ssh-add "$PWD/$k" >/dev/null 2>&1 || fail "could not add $k to the agent"
              done
            }

            # Match the config's Host pattern while connecting to our own sshd. No
            # muxing, or every case after the first reuses the first connection.
            probe() {
              offered=$(timeout 20 ssh -F "$cfg" -vv -o IdentityAgent="''${SSH_AUTH_SOCK:-none}" \
                -o HostName=127.0.0.1 -o Port=$port -o StrictHostKeyChecking=no \
                -o UserKnownHostsFile=/dev/null -o ControlMaster=no -o ControlPath=none \
                -o BatchMode=yes -o ConnectTimeout=10 "nosuchuser@$1" true 2>&1 |
                grep -o 'Offering public key:.*SHA256:[A-Za-z0-9+/]*' | awk '{print $NF}' || true)
            }
            first() { printf '%s\n' "$offered" | head -1; }
            count() { printf '%s' "$offered" | grep -c . || true; }

            echo "--- [${name}] a forge offers my key first when the agent has it"
            load primary spare
            probe github.com
            [ "$(first)" = "$(fp "$PWD/primary.pub")" ] ||
              fail "the first key offered to a forge was '$(first)', not primary"

            echo "--- [${name}] a key the agent cannot sign with loses its place"
            load spare
            probe github.com
            # ssh still offers the named file last, having demoted it behind
            # every key the agent can actually sign with.
            [ "$(first)" = "$(fp "$PWD/spare.pub")" ] ||
              fail "the agent's usable key was not offered before the unbacked one"

            echo "--- [${name}] a missing key file is a preference, not a requirement"
            mv "$pwhome/.ssh/primary.pub" "$PWD/primary.pub.stashed"
            load primary spare
            probe github.com
            [ "$(count)" -gt 0 ] ||
              fail "an absent primary.pub stopped the agent's keys being offered"
            mv "$PWD/primary.pub.stashed" "$pwhome/.ssh/primary.pub"

            echo "--- [${name}] an unlisted host is offered my key, never denied"
            load primary spare
            probe unlisted.invalid
            [ "$(first)" = "$(fp "$PWD/primary.pub")" ] ||
              fail "a host I have not listed led with '$(first)' instead of primary"

            echo "--- [${name}] one of my own hosts is offered the agent's keys"
            load primary spare
            probe "$granted"
            [ "$(count)" -gt 0 ] || fail "$granted was offered no key despite a loaded agent"

            echo "--- [${name}] with no agent at all it gives up instead of prompting"
            old_sock=$SSH_AUTH_SOCK
            unset SSH_AUTH_SOCK
            rc=0
            timeout 20 ssh -F "$cfg" -o IdentityAgent=none -o HostName=127.0.0.1 -o Port=$port \
              -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ControlMaster=no \
              -o ControlPath=none -o BatchMode=yes "nosuchuser@github.com" true >/dev/null 2>&1 || rc=$?
            [ "$rc" != 0 ] || fail "a forge authenticated with no agent and no private key"
            [ "$rc" != 124 ] || fail "a forge hung waiting on input instead of giving up"
            export SSH_AUTH_SOCK=$old_sock

            ssh-agent -k >/dev/null 2>&1 || true
            touch $out
    '';
in
  lib.throwIf (withAgentBlock == null || withoutAgentBlock == null)
  "ssh/credential-tests.nix: need one host with an IdentityAgent block and one without"
  {
    resolves = map resolution [withAgentBlock withoutAgentBlock];
    offers = wireOffers withoutAgentBlock;
  }
