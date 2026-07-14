# pdal 2.9.3 doesn't compile against nixpkgs' gdal 3.13: GDALDataset::GetMetadata()
# now returns CSLConstList (const char* const*), but Raster.cpp assigns it to a
# `char**`, so the build fails with an invalid-conversion error. Upstream fixed
# this on master by declaring the variable CSLConstList; backport that one line.
# pdal is pulled in transitively via vtk -> freecad. Drop once nixpkgs bumps pdal
# to a release containing the fix.
# CHECK-ATTR: pdal
_: _final: prev: {
  pdal = prev.pdal.overrideAttrs (old: {
    postPatch =
      (old.postPatch or "")
      + ''
        substituteInPlace pdal/private/gdal/Raster.cpp \
          --replace-fail 'char **papszMetadata = NULL;' 'CSLConstList papszMetadata = NULL;'
      '';
  });
}
