# Plans hides for one window snapshot; unhides only pids it hid, and hides each once so Cmd+Tab back sticks.
def coveredBy($fullscreen):
  ($fullscreen | map(.workspace.id)) as $workspaces
  | ([.[] | select(.workspace.id as $id | any($workspaces[]; . == $id)) | .pid] | unique)
    - ($fullscreen | map(.pid));

(.result.payload.windows // null) as $windows
| if $windows == null then {hide: [], show: [], hidden: $hidden}
  else
    [$windows[] | select(.isFullscreen and .workspace.id != null)] as $fullscreen
    # Hide only behind what is on screen, but keep hidden while any workspace stays fullscreen.
    | ($windows | coveredBy([$fullscreen[] | select(.isVisible)])) as $onScreen
    | ($windows | coveredBy($fullscreen)) as $covered
    | ([$windows[] | select(.isAppHidden) | .pid] | unique) as $alreadyHidden
    | ($onScreen - $hidden - $alreadyHidden) as $hide
    | ($hidden - $covered) as $show
    | {hide: $hide, show: $show, hidden: ($hidden - $show + $hide)}
  end
