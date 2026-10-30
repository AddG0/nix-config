# Workarounds for upstream Deckcord bugs on current Steam (drop when fixed):
#   - retry-init.patch: survive loading before Steam's CEF is ready.
#   - postPatch: patchMenu()'s "Discord" Steam-menu item no longer injects (its
#     MainNavMenuContainer React-tree walk stopped matching), and the logged-out
#     QAM panel only points there — a first-login dead end. Add an Open-Discord
#     button to that panel so the /discord route stays reachable.
#   - main.py: the voice backend's dbus/pipewire paths hardcode SteamOS's uid 1000.
_: _final: prev: {
  addg = prev.addg.overrideScope (_: aprev: {
    decky = aprev.decky.overrideScope (_: nprev: {
      deckcord = nprev.deckcord.overrideAttrs (o: {
        patches = (o.patches or []) ++ [./retry-init.patch];
        postPatch =
          (o.postPatch or "")
          + ''
            substituteInPlace dist/index.js \
              --replace-fail '"from the Steam Menu and login.")' '"from the Steam Menu and login."),window.SP_REACT.createElement("button",{onClick:()=>window.DFL.Router.Navigate("/discord"),style:{marginTop:"10px",padding:"8px",cursor:"pointer"}},"Open Discord to log in")'
            substituteInPlace main.py \
              --replace-fail 'import sys' $'import sys\nfrom os import getuid' \
              --replace-fail '"unix:path=/run/user/1000/bus"' 'f"unix:path=/run/user/{getuid()}/bus"' \
              --replace-fail '"/run/user/1000"' 'f"/run/user/{getuid()}"'
          '';
      });
    });
  });
}
