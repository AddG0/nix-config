// Pure-JS helpers shared between the QML runtime and the Node test harness.
// Anything Qt-specific (Quickshell.env, Process, etc.) stays in shell.qml;
// this file is plain JavaScript so Node can load it via require().

function applyTransform(monitor) {
  var rotated =
    monitor.transform === 1 ||
    monitor.transform === 3 ||
    monitor.transform === 5 ||
    monitor.transform === 7;
  return Object.assign({}, monitor, {
    _logicalW: rotated ? monitor.height : monitor.width,
    _logicalH: rotated ? monitor.width : monitor.height,
  });
}

function computeBounds(monitors) {
  var ms = monitors.map(applyTransform);
  var minX = Infinity;
  var minY = Infinity;
  var maxX = -Infinity;
  var maxY = -Infinity;
  for (var i = 0; i < ms.length; i++) {
    var m = ms[i];
    minX = Math.min(minX, m.x);
    minY = Math.min(minY, m.y);
    maxX = Math.max(maxX, m.x + m._logicalW);
    maxY = Math.max(maxY, m.y + m._logicalH);
  }
  return {
    monitors: ms,
    minX: minX,
    minY: minY,
    boundsW: Math.max(1, maxX - minX),
    boundsH: Math.max(1, maxY - minY),
  };
}

// Per-output folder pair. `display` is where thumbnails are read from
// (a pre-generated cache for fast loads); `apply` is the source path
// passed to wpaperctl on click (may be a rotated cache for transformed
// outputs). For outputs not in folderMap (e.g. transient laptop HDMI),
// `defaults` provides the fallback {display, apply} pair.
function foldersFor(folderMap, defaults, outputName) {
  if (folderMap && folderMap[outputName]) return folderMap[outputName];
  return defaults;
}

// CommonJS export — Node sees this; QML's JS engine ignores it because
// `module` is undefined there, which is harmless.
if (typeof module !== "undefined") {
  module.exports = { applyTransform, computeBounds, foldersFor };
}
