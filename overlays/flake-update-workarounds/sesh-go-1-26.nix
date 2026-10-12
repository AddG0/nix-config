# nixpkgs builds sesh with Go 1.27, whose export data (v5) mockery 3.8.0 can't
# read, so its checkPhase and sesh's `mockery` preBuild fail. sesh only needs 1.26.
# CHECK-ATTR: sesh
_: final: prev: {
  sesh = prev.sesh.override {buildGo127Module = final.buildGoModule;};
}
