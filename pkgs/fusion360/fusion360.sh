#!/usr/bin/env bash
# Self-contained Autodesk Fusion 360 launcher for Wine.
#
#   fusion360               install into $FUSION360_HOME on first run, then launch;
#                           launch directly on every run afterwards.
#   fusion360 --reinstall   rebuild the Wine prefix from scratch.
#   fusion360 --uninstall   remove the prefix and all state.
#   fusion360 --prefix      print the Wine prefix path.
#
# Fusion is proprietary, online-activated and non-redistributable, so it cannot
# live in the Nix store: the first run downloads Autodesk's installer and the
# winetricks verbs into a mutable prefix under $HOME. The Wine build is pinned by
# the package.
#
# No `set -e`: Wine and winetricks routinely exit non-zero on benign conditions,
# so we drive best-effort steps explicitly and verify the result at the end.
set -uo pipefail

FUSION360_HOME="${FUSION360_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/fusion360}"
export WINEPREFIX="$FUSION360_HOME/prefix"
export WINEARCH=win64
downloads="$FUSION360_HOME/downloads"
marker="$FUSION360_HOME/.installed"

# Substituted at build time.
share="@share@"

fusion_installer_url="https://dl.appstreaming.autodesk.com/production/installers/Fusion%20Admin%20Install.exe"

# Let async Wine work flush briefly, then kill anything still running. An
# unbounded `wineserver -w` deadlocks here: some installers leave a background
# process alive, so the server never goes idle.
settle_wine() {
  WINEPREFIX="$WINEPREFIX" timeout 20 wineserver -w 2>/dev/null || true
  WINEPREFIX="$WINEPREFIX" wineserver -k9 2>/dev/null || true
}
# Shut down the launched app. `wineserver -k` sends SIGINT first so Wine destroys
# its X windows - a SIGKILL'd XWayland window lingers as a frozen ghost on Hyprland
# - bounded so a stuck app can't hang the terminal, then SIGKILL any stragglers.
stop_wine() {
  WINEPREFIX="$WINEPREFIX" timeout 8 wineserver -k 2>/dev/null
  WINEPREFIX="$WINEPREFIX" wineserver -k9 2>/dev/null
}

wt() { WINEPREFIX="$WINEPREFIX" WINEDLLOVERRIDES="mscoree,mshtml=" winetricks -q "$@"; }
reg() { WINEPREFIX="$WINEPREFIX" wine reg add "$1" /v "$2" /t REG_SZ /d "$3" /f &>/dev/null; }

find_newest() { find "$WINEPREFIX" -name "$1" -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -n1 | cut -d' ' -f2-; }

# NMachineSpecificOptions.xml pins the renderers Wine needs: DX11 (DXVK->Vulkan) for
# the 3D viewport - auto-detect picks OpenGL, which page-faults on NVIDIA under Wine -
# and gl for the embedded Chromium, whose default present path renders black (Wine
# has no DirectComposition).
configure_graphics() {
  local u="$WINEPREFIX/drive_c/users/$USER"

  # Re-copied every launch so a config change (e.g. DX9 -> DX11) reaches an
  # already-installed prefix.
  local d
  for d in "$u/AppData/Roaming" "$u/AppData/Local" "$u/Application Data"; do
    mkdir -p "$d/Autodesk/Neutron Platform/Options"
    cp -f "$share/NMachineSpecificOptions.xml" "$d/Autodesk/Neutron Platform/Options/NMachineSpecificOptions.xml"
  done

  # DXVK d3d overrides only need setting once (each is a slow wine invocation).
  # d3d9 stays builtin - the nav bar's CEF browser wants Wine's DX9.
  local regmarker="$WINEPREFIX/.dxvk-overrides-done"
  [[ -f $regmarker ]] && return 0
  reg 'HKCU\Software\Wine\DllOverrides' '*d3d10core' native
  reg 'HKCU\Software\Wine\DllOverrides' '*d3d11' native
  reg 'HKCU\Software\Wine\DllOverrides' '*d3d9' builtin
  reg 'HKCU\Software\Wine\DllOverrides' '*dxgi' native
  touch "$regmarker"
}

deploy_fusion() {
  echo "==> Downloading and running the Autodesk Fusion installer"
  curl -fL "$fusion_installer_url" -o "$downloads/FusionInstaller.exe"
  # The Admin installer no-ops on a bare --quiet; --process deploy streams and
  # installs Fusion into the webdeploy tree (~7 GB). Re-running restores any
  # files we've overwritten. --no-auto-launch keeps it headless.
  WINEPREFIX="$WINEPREFIX" timeout -k 5m 30m wine "$downloads/FusionInstaller.exe" \
    --globalinstall --process deploy --quiet --no-auto-launch
  settle_wine
}

install_fusion() {
  echo "==> First-run setup - building the Wine prefix at $WINEPREFIX"
  echo "    This downloads several GB (Autodesk installer + Wine components) and takes a while."
  mkdir -p "$downloads"

  # Create the prefix without the Mono/Gecko prompts; dotnet452 below supplies .NET.
  WINEDLLOVERRIDES="mscoree,mshtml=" WINEPREFIX="$WINEPREFIX" wineboot --init
  settle_wine

  # The Fusion installer looks for its payload under the prefix's Downloads dir.
  rm -rf "$WINEPREFIX/drive_c/users/$USER/Downloads"
  ln -sfn "$downloads" "$WINEPREFIX/drive_c/users/$USER/Downloads"

  echo "==> Installing runtime libraries via winetricks"
  wt atmlib gdiplus arial corefonts cjkfonts dotnet452 msxml4 msxml6 vcrun2017 fontsmooth=rgb winhttp win10
  wt cjkfonts # occasionally needs a second pass
  wt win11    # some verbs reset the Windows version to XP
  wt dxvk     # the wined3d OpenGL fallback is unusably slow for Fusion
  settle_wine

  echo "==> Applying registry tweaks"
  reg 'HKCU\Software\Wine\DllOverrides' adpclientservice.exe ''     # silence telemetry
  reg 'HKCU\Software\Wine\DllOverrides' AdCefWebBrowser.exe builtin # nav bar needs builtin DX9
  reg 'HKCU\Software\Wine\DllOverrides' msvcp140 native             # use Fusion's bundled VC++ redist
  reg 'HKCU\Software\Wine\DllOverrides' mfc140u native
  reg 'HKCU\Software\Wine\DllOverrides' bcp47langs ''          # fixes the sign-in flow
  reg 'HKCU\Software\Wine\DllOverrides' winemenubuilder.exe '' # don't spawn Linux .desktop/menu cruft
  settle_wine

  deploy_fusion
  [[ -n "$(find_newest Fusion360.exe)" ]] || {
    echo "Install failed; try 'fusion360 --reinstall'." >&2
    exit 1
  }
  configure_graphics

  touch "$marker"
  echo "==> Setup complete."
}

launch_fusion() {
  local exe
  exe="$(find_newest Fusion360.exe)"
  if [[ -z $exe ]]; then
    echo "Fusion360.exe not found in $WINEPREFIX." >&2
    echo "The install did not complete. Run 'fusion360 --reinstall'." >&2
    exit 1
  fi
  configure_graphics

  # --no-sandbox because Wine has none. Don't add --disable-gpu: it kills the gl backend
  # (configure_graphics) that keeps the panels off the black DirectComposition path.
  local chromium_flags="--no-sandbox"

  # Make the embedded Chromium render in software so it stops painting black: its gl
  # backend otherwise grabs NVIDIA's EGL, which can't draw under XWayland. Pin EGL to
  # Mesa AND force llvmpipe - LIBGL_ALWAYS_SOFTWARE alone is ignored once NVIDIA's EGL is
  # picked. Vulkan/DXVK is untouched, so the 3D viewport stays GPU-accelerated.
  local egl_env=()
  local mesa_egl=/run/opengl-driver/share/glvnd/egl_vendor.d/50_mesa.json
  [[ -f $mesa_egl ]] && egl_env=(__EGL_VENDOR_LIBRARY_FILENAMES="$mesa_egl")

  # Run Wine as a child (not exec) so Ctrl+C / window-close can drive stop_wine
  # instead of the shell waiting on Wine's own slow shutdown.
  env \
    "${egl_env[@]}" \
    LIBGL_ALWAYS_SOFTWARE=1 \
    DXVK_LOG_LEVEL=none WINEDEBUG=-all,+err \
    QTWEBENGINE_DISABLE_SANDBOX=1 \
    QTWEBENGINE_CHROMIUM_FLAGS="$chromium_flags" \
    WINEPREFIX="$WINEPREFIX" wine "$exe" &
  local winepid=$!
  trap 'stop_wine; exit 0' INT TERM HUP
  wait "$winepid"
  stop_wine
}

case "${1:-}" in
--reinstall)
  rm -rf "$WINEPREFIX" "$marker"
  install_fusion
  launch_fusion
  ;;
--repair)
  # Rebuild only the Fusion install, keeping the winetricks prefix. --process
  # deploy won't repair individual files, so we drop the whole webdeploy tree
  # to force a clean re-fetch of Fusion's own DLLs (~7 GB, no winetricks redo).
  rm -rf "$WINEPREFIX/drive_c/Program Files/Autodesk/webdeploy"
  deploy_fusion
  configure_graphics
  launch_fusion
  ;;
--uninstall)
  rm -rf "$FUSION360_HOME"
  echo "Removed $FUSION360_HOME"
  ;;
--prefix) echo "$WINEPREFIX" ;;
--adskidmgr)
  # Browser login callback: hand the adskidmgr:// token to the Identity Manager
  # so the waiting app completes sign-in.
  exe="$(find_newest AdskIdentityManager.exe)"
  [[ -n $exe ]] || {
    echo "AdskIdentityManager.exe not found; is Fusion installed?" >&2
    exit 1
  }
  exec env WINEPREFIX="$WINEPREFIX" WINEDEBUG=-all wine "$exe" "${2:-}"
  ;;
"")
  [[ -f $marker ]] || install_fusion
  launch_fusion
  ;;
*)
  echo "usage: fusion360 [--reinstall|--repair|--uninstall|--prefix]" >&2
  exit 2
  ;;
esac
