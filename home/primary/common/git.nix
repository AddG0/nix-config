{
    config,
    ...
}: 

{
  programs.git = {
    includes = [
      {
        # use different email & name for work
        path = "${config.home.homeDirectory}/home/ShipperHQ/.gitconfig";
        condition = "gitdir:${config.home.homeDirectory}/home/ShipperHQ/**";
      }
    ];
  };
}
