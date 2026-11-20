# Lowers each new floating window under a fullscreen window on its workspace, so popups wait behind a fullscreen video.
socket="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

# Hyprland maps every new floating window above a fullscreen one; alterzorder bottom clears that.
lower_if_over_fullscreen() {
  local window=$1 clients covered=0 reply status=0
  if ! clients=$(hyprctl -j clients); then
    echo "listing clients for new window $window failed" >&2
    return
  fi

  # Pinned windows (PiP) stay above fullscreen whatever their z-order.
  jq -e --arg window "$window" '
    (map(select(.address == $window)) | first) as $new
    | $new != null and $new.floating and $new.fullscreen == 0 and ($new.pinned | not)
      and any(.[]; .workspace.id == $new.workspace.id and .fullscreen != 0)
  ' <<<"$clients" >/dev/null || covered=$?
  case $covered in
  0) ;;
  1) return ;;
  *)
    echo "reading clients for new window $window failed (jq exit $covered)" >&2
    return
    ;;
  esac

  reply=$(hyprctl dispatch alterzorder "bottom,address:$window" 2>&1) || status=$?
  if [ "$status" -ne 0 ] || [ "$reply" != ok ]; then
    echo "lowering window $window under fullscreen failed (hyprctl exit $status): $reply" >&2
  fi
}

# openwindow>>ADDRESS,WORKSPACE,CLASS,TITLE
while IFS= read -r event; do
  case "$event" in
  # Safe Eyes breaks must cover the video; its own listener fullscreens them.
  "openwindow>>"*",io.github.slgobinath.SafeEyes,"*) ;;
  "openwindow>>"*)
    window="${event#openwindow>>}"
    lower_if_over_fullscreen "0x${window%%,*}"
    ;;
  esac
done < <(socat -u UNIX-CONNECT:"$socket" -)

echo "Hyprland event socket $socket closed" >&2
exit 1
