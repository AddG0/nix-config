# The event listener behind ./default.nix, built from its tools so tests can pass stand-ins.
{
  writeShellApplication,
  hyprland,
  jq,
  socat,
}:
writeShellApplication {
  name = "hyprland-popups-under-fullscreen";
  runtimeInputs = [hyprland jq socat];
  text = builtins.readFile ./listener.sh;
}
