# nixpkgs' gdal 3.13.1 runs `test_zarr_read_simple_sharding` in its installCheck.
# The test opens a sharded Zarr v3 with CACHE_TILE_PRESENCE=YES and asserts a
# `zarr.json.gmac` tile-presence cache sidecar is written — but that cache isn't
# produced in the gdal-minimal build, so the assert fails and the derivation
# breaks. gdal-minimal is pulled in transitively via pdal. Drop once nixpkgs
# gates this test on the minimal feature set (or upstream fixes it).
# CHECK-ATTR: gdalMinimal
_: _final: prev: {
  gdal = prev.gdal.overrideAttrs (old: {
    disabledTests =
      (old.disabledTests or [])
      ++ ["test_zarr_read_simple_sharding"];
  });
}
