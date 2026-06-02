const { test } = require("node:test");
const assert = require("node:assert/strict");
const Util = require("./util.js");

test("applyTransform: landscape monitor leaves dims unchanged", () => {
  const m = Util.applyTransform({ width: 3840, height: 2160, transform: 0 });
  assert.equal(m._logicalW, 3840);
  assert.equal(m._logicalH, 2160);
});

test("applyTransform: rotated monitor (transform=3) swaps dims", () => {
  const m = Util.applyTransform({ width: 1920, height: 1080, transform: 3 });
  assert.equal(m._logicalW, 1080);
  assert.equal(m._logicalH, 1920);
});

test("applyTransform: 90° rotation (transform=1) swaps dims", () => {
  const m = Util.applyTransform({ width: 1920, height: 1080, transform: 1 });
  assert.equal(m._logicalW, 1080);
  assert.equal(m._logicalH, 1920);
});

test("applyTransform: flipped-only (transform=4) preserves orientation", () => {
  const m = Util.applyTransform({ width: 1920, height: 1080, transform: 4 });
  assert.equal(m._logicalW, 1920);
  assert.equal(m._logicalH, 1080);
});

test("computeBounds: single landscape monitor", () => {
  const b = Util.computeBounds([
    { x: 0, y: 0, width: 1920, height: 1080, transform: 0 },
  ]);
  assert.equal(b.boundsW, 1920);
  assert.equal(b.boundsH, 1080);
  assert.equal(b.minX, 0);
  assert.equal(b.minY, 0);
});

test("computeBounds: rotated monitor uses logical dims", () => {
  const b = Util.computeBounds([
    { x: 0, y: 0, width: 1920, height: 1080, transform: 3 },
  ]);
  assert.equal(b.boundsW, 1080);
  assert.equal(b.boundsH, 1920);
});

test("computeBounds: three-monitor layout (demon's actual setup)", () => {
  const b = Util.computeBounds([
    { x: 0, y: 0, width: 3840, height: 2160, transform: 0 }, // DP-1
    { x: 3840, y: 0, width: 3840, height: 2160, transform: 0 }, // DP-3
    { x: 7680, y: 240, width: 1920, height: 1080, transform: 3 }, // DP-2 portrait
  ]);
  assert.equal(b.minX, 0);
  assert.equal(b.minY, 0);
  // Total width spans DP-1 + DP-3 + DP-2(rotated to 1080 wide) = 8760
  assert.equal(b.boundsW, 8760);
  // Total height spans top (0) down to bottom of portrait DP-2 (240+1920 = 2160)
  assert.equal(b.boundsH, 2160);
});

test("computeBounds: negative-x monitor (output left of origin)", () => {
  const b = Util.computeBounds([
    { x: -1920, y: 0, width: 1920, height: 1080, transform: 0 },
    { x: 0, y: 0, width: 1920, height: 1080, transform: 0 },
  ]);
  assert.equal(b.minX, -1920);
  assert.equal(b.boundsW, 3840);
});

const defaults = { display: "/thumbs/default", apply: "/src/default" };

test("foldersFor: returns explicit display+apply pair when present", () => {
  const map = { "DP-1": { display: "/thumbs/left", apply: "/cache/left" } };
  assert.deepEqual(Util.foldersFor(map, defaults, "DP-1"), {
    display: "/thumbs/left",
    apply: "/cache/left",
  });
});

test("foldersFor: falls back to defaults for unknown output", () => {
  assert.deepEqual(Util.foldersFor({}, defaults, "DP-99"), defaults);
});

test("foldersFor: handles null folderMap gracefully", () => {
  assert.deepEqual(Util.foldersFor(null, defaults, "DP-1"), defaults);
});
