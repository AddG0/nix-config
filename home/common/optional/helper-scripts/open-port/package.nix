# open-port: opens a NixOS firewall port for a while, on every interface or one, with its zsh completion.
{
  symlinkJoin,
  writeShellApplication,
  writeTextFile,
  iptables,
}: let
  script = writeShellApplication {
    name = "open-port";
    runtimeInputs = [iptables];
    text = builtins.readFile ./open-port.sh;
  };

  zshCompletion = writeTextFile {
    name = "open-port-zsh-completion";
    destination = "/share/zsh/site-functions/_open-port";
    text = builtins.readFile ./_open-port;
  };
in
  symlinkJoin {
    name = "open-port";
    paths = [script zshCompletion];
    meta.mainProgram = "open-port";
  }
