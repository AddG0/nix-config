# Workarounds for upstream Deckcord bugs on current Steam (drop when fixed):
#   - retry-init.patch: survive loading before Steam's CEF is ready.
#   - postPatch: patchMenu()'s "Discord" Steam-menu item no longer injects (its
#     MainNavMenuContainer React-tree walk stopped matching), and the logged-out
#     QAM panel only points there — a first-login dead end. Add an Open-Discord
#     button to that panel so the /discord route stays reachable.
_: _final: prev: {
  decky =
    prev.decky
    // {
      deckcord = prev.decky.deckcord.overrideAttrs (o: {
        patches = (o.patches or []) ++ [./retry-init.patch];
        postPatch =
          (o.postPatch or "")
          + ''
            substituteInPlace dist/index.js \
              --replace-fail '"from the Steam Menu and login.")' '"from the Steam Menu and login."),window.SP_REACT.createElement("button",{onClick:()=>window.DFL.Router.Navigate("/discord"),style:{marginTop:"10px",padding:"8px",cursor:"pointer"}},"Open Discord to log in")'
          '';
      });
    };
}
