{optional, ...}: {
  gaming.home = with optional.home.gaming; [core reset-steam-prefix sens-convert steam];
}
