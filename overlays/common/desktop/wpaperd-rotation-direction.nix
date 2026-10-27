# wpaperd rotates 90°/270° outputs the wrong way, flipping the wallpaper; danyspin97/wpaperd#199.
_: _final: prev: {
  wpaperd = prev.wpaperd.overrideAttrs (old: {
    patches = (old.patches or []) ++ [./wpaperd-rotation-direction.patch];
  });
}
