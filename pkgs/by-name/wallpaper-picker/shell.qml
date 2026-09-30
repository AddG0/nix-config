// Quickshell wallpaper picker — entry point.
//
// Window layout (ColumnLayout, top-to-bottom):
//   MonitorSelector   mini visual layout, click to switch monitor
//   Text              "Wallpapers · <selected>" title
//   ThumbnailGrid     wallpapers for the selected monitor
//
// Component tree:
//   shell.qml           this file: state + IPC + window composition
//   MonitorSelector.qml proportional strip of monitor buttons
//   MonitorButton.qml   one clickable monitor outline
//   ThumbnailGrid.qml   GridView fed by FolderListModel
//   Thumbnail.qml       single hoverable/clickable image cell
//   util.js             pure-JS helpers (covered by test.js)
//
// Env vars from the wrapper script:
//   WP_HYPRCTL / WP_WPAPERCTL    binary paths
//   WP_FOLDERS                    JSON: {<output>: {display, apply}}
//   WP_DEFAULTS                   JSON: {display, apply} fallback when output isn't in WP_FOLDERS
//   WP_BG / WP_FG / WP_BORDER    stylix colors
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "util.js" as Util

Scope {
  id: root

  // ─── Layout constants ─────────────────────────────────────────────────
  readonly property int outerPad: 16
  readonly property int innerGap: 12
  readonly property int selectorHeight: 240

  // ─── State ────────────────────────────────────────────────────────────
  property var monitors: []
  property var folderMap: ({})
  property var defaultFolders: ({ display: "", apply: "" })
  property var currentWallpapers: ({})  // output -> abs path of current wallpaper
  property var oledOutputs: []           // outputs owned by wallpaper-guard (read-only here)
  property string selectedOutput: ""
  property real boundsX: 0
  property real boundsY: 0
  property real boundsW: 1
  property real boundsH: 1

  // ─── Theme (frozen at startup) ────────────────────────────────────────
  readonly property string bg: Quickshell.env("WP_BG") || "#1e1e2e"
  readonly property string fg: Quickshell.env("WP_FG") || "#cdd6f4"
  readonly property string borderColor: Quickshell.env("WP_BORDER") || "#7f849c"

  // ─── Init ─────────────────────────────────────────────────────────────
  Component.onCompleted: {
    var foldersRaw = Quickshell.env("WP_FOLDERS");
    if (foldersRaw && foldersRaw.length > 0) {
      try {
        root.folderMap = JSON.parse(foldersRaw);
      } catch (e) {
        console.warn("wallpaper-picker: WP_FOLDERS is not valid JSON:", e.message);
      }
    }
    var defaultsRaw = Quickshell.env("WP_DEFAULTS");
    if (defaultsRaw && defaultsRaw.length > 0) {
      try {
        root.defaultFolders = JSON.parse(defaultsRaw);
      } catch (e) {
        console.warn("wallpaper-picker: WP_DEFAULTS is not valid JSON:", e.message);
      }
    }
    var oledRaw = Quickshell.env("WP_OLED_OUTPUTS");
    if (oledRaw && oledRaw.length > 0) {
      try {
        root.oledOutputs = JSON.parse(oledRaw);
      } catch (e) {
        console.warn("wallpaper-picker: WP_OLED_OUTPUTS is not valid JSON:", e.message);
      }
    }
    monitorQuery.running = true;
    currentQuery.running = true;
  }

  // ─── Backends ─────────────────────────────────────────────────────────
  Process {
    id: monitorQuery
    command: [Quickshell.env("WP_HYPRCTL"), "monitors", "-j"]
    stdout: StdioCollector {
      onStreamFinished: root.applyMonitors(text)
    }
  }

  // `wpaperctl all-wallpapers` prints `<output>: <abspath>` per line for
  // every output. Parsed into currentWallpapers so each monitor button
  // can show its current image. (`get-wallpaper` is single-monitor only.)
  Process {
    id: currentQuery
    command: [Quickshell.env("WP_WPAPERCTL"), "all-wallpapers"]
    stdout: StdioCollector {
      onStreamFinished: root.parseCurrent(text)
    }
  }

  Process {
    id: setWallpaper
    command: []
    // Exit only after wpaperctl actually finishes — calling Qt.exit() at
    // click time tears down the engine before the child has a chance to
    // run, so the wallpaper never actually changes. Surface non-zero
    // exits so a silent failure (bad path, daemon gone) doesn't just
    // close the picker with no feedback.
    onExited: (exitCode, exitStatus) => {
      if (exitCode !== 0) {
        console.warn("wpaperctl set failed: exitCode=" + exitCode + " status=" + exitStatus);
      }
      Qt.exit(exitCode);
    }
  }

  // ─── Behaviour ────────────────────────────────────────────────────────
  function applyMonitors(text) {
    var b = Util.computeBounds(JSON.parse(text));
    // Drop OLED outputs — wallpaper-guard forces them to black, so a
    // picker click there would immediately revert and read as a bug.
    var visible = b.monitors.filter(function (m) {
      return root.oledOutputs.indexOf(m.name) < 0;
    });
    // Recompute bounds against the visible set so the layout doesn't
    // leave dead space where the OLED used to be.
    var b2 = Util.computeBounds(visible.map(function (m) {
      // computeBounds expects raw monitors; strip the _logicalW/H it
      // already injected so it doesn't double-transform.
      var copy = Object.assign({}, m);
      delete copy._logicalW;
      delete copy._logicalH;
      return copy;
    }));
    boundsX = b2.minX;
    boundsY = b2.minY;
    boundsW = b2.boundsW;
    boundsH = b2.boundsH;
    monitors = b2.monitors;
    if (selectedOutput === "" && monitors.length > 0) {
      // Default to the visually-first monitor (top row, leftmost) rather
      // than monitors[0], which is whatever order the compositor
      // enumerated outputs in — often the rightmost panel.
      var ordered = monitors.slice().sort(function (a, b) {
        if (a.y !== b.y) return a.y - b.y;
        return a.x - b.x;
      });
      selectedOutput = ordered[0].name;
    }
  }

  function applyWallpaper(filePath, outputName) {
    setWallpaper.command = [Quickshell.env("WP_WPAPERCTL"), "set", filePath, outputName];
    setWallpaper.running = true;
  }

  function foldersFor(outputName) {
    return Util.foldersFor(root.folderMap, root.defaultFolders, outputName);
  }

  function cycleSelectedMonitor(direction) {
    if (monitors.length === 0) return;
    // Visual reading order: top-to-bottom, then left-to-right within
    // each row. Independent of hyprctl's array order, which is arbitrary.
    var ordered = monitors.slice().sort(function (a, b) {
      if (a.y !== b.y) return a.y - b.y;
      return a.x - b.x;
    });
    var idx = 0;
    for (var i = 0; i < ordered.length; i++) {
      if (ordered[i].name === selectedOutput) { idx = i; break; }
    }
    var next = (idx + direction + ordered.length) % ordered.length;
    selectedOutput = ordered[next].name;
  }

  function parseCurrent(text) {
    var map = {};
    var lines = text.split("\n");
    for (var i = 0; i < lines.length; i++) {
      var m = lines[i].match(/^([^:]+):\s*(.+)$/);
      if (m) map[m[1].trim()] = m[2].trim();
    }
    root.currentWallpapers = map;
  }

  // Translate an absolute wallpaper path (under baseDir or rotatedCache)
  // into the corresponding thumb path, by combining the output's display
  // folder with the wallpaper's basename. wpaperd resolves symlinks
  // before reporting, so a wallpaper picked from a wallpapers.images
  // entry comes back as /nix/store/<hash>-<name> — strip the
  // 32-char nix-store hash prefix so the thumb lookup hits its true
  // filename. Returns "" if no current wallpaper known for that output.
  function currentThumb(outputName) {
    var current = root.currentWallpapers[outputName];
    if (!current) return "";
    var basename = current.substring(current.lastIndexOf("/") + 1);
    var nixMatch = basename.match(/^[a-z0-9]{32}-(.+)$/);
    if (nixMatch) basename = nixMatch[1];
    return root.foldersFor(outputName).display + "/" + basename;
  }

  // ─── UI ───────────────────────────────────────────────────────────────
  FloatingWindow {
    title: "Wallpaper picker"
    implicitWidth: 1600
    implicitHeight: 900
    color: root.bg
    visible: true

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: root.outerPad
      spacing: root.innerGap

      MonitorSelector {
        Layout.fillWidth: true
        Layout.preferredHeight: root.selectorHeight
        monitors: root.monitors
        boundsX: root.boundsX
        boundsY: root.boundsY
        boundsW: root.boundsW
        boundsH: root.boundsH
        selectedOutput: root.selectedOutput
        labelColor: root.fg
        outlineColor: root.borderColor
        selectedColor: root.fg
        currentThumb: name => root.currentThumb(name)
        onChose: name => root.selectedOutput = name
      }

      ThumbnailGrid {
        Layout.fillWidth: true
        Layout.fillHeight: true
        folderPath: root.selectedOutput.length > 0
          ? root.foldersFor(root.selectedOutput).display
          : ""
        outlineColor: root.borderColor
        labelColor: root.fg
        // Translate the clicked file's basename through the `apply` folder
        // (which may be a rotated cache for transformed outputs). Don't
        // exit here — setWallpaper.onExited handles teardown.
        onPick: fileName => {
          var applyFolder = root.foldersFor(root.selectedOutput).apply;
          root.applyWallpaper(applyFolder + "/" + fileName, root.selectedOutput);
        }
        onCycleMonitor: direction => root.cycleSelectedMonitor(direction)
      }
    }
  }
}
