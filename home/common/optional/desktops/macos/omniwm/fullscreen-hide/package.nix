# Toggles OmniWM fullscreen and hides the apps tiled behind it, so a transparent window shows the wallpaper.
{
  stdenv,
  writeShellApplication,
  jq,
  omniwm,
}: let
  # Compiled because osascript's JXA startup alone took 52ms of a keypress.
  appVisibility = stdenv.mkDerivation {
    name = "app-visibility";
    src = ./app-visibility.m;
    dontUnpack = true;
    buildPhase = "$CC -fobjc-arc -framework AppKit -o app-visibility $src";
    installPhase = "install -Dm755 app-visibility $out/bin/app-visibility";
  };
in
  writeShellApplication {
    name = "omniwm-toggle-fullscreen";
    runtimeInputs = [jq omniwm appVisibility];
    text = ''
      # Remembers which apps this hid, so the next toggle unhides only those.
      state="$HOME/.local/state/omniwm-fullscreen-hide.json"
      hidden='[]'
      if [ -e "$state" ]; then
        hidden=$(<"$state")
        jq -e arrays >/dev/null <<<"$hidden" || {
          printf '%(%FT%T%z)T ignoring unreadable state %s; apps it listed stay hidden\n' -1 "$state" >&2
          hidden='[]'
        }
      fi

      omniwmctl command toggle-fullscreen >/dev/null
      plan=$(omniwmctl query windows --format json \
        | jq -r --argjson hidden "$hidden" -f ${./plan.jq} \
        | jq -r '(.hide | join(" ")), (.show | join(" ")), (.hidden | tojson)')
      { read -r hide; read -r show; read -r hidden; } <<<"$plan"

      if [ -n "$hide" ]; then
        printf '%(%FT%T%z)T hide %s\n' -1 "$hide"
        # shellcheck disable=SC2086 # pid list
        app-visibility hide $hide
      fi
      if [ -n "$show" ]; then
        printf '%(%FT%T%z)T unhide %s\n' -1 "$show"
        # shellcheck disable=SC2086 # pid list
        app-visibility unhide $show
      fi
      [ -d "''${state%/*}" ] || mkdir -p "''${state%/*}"
      echo "$hidden" >"$state.tmp" && mv "$state.tmp" "$state"
    '';
  }
