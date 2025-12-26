# Loader component definitions for mmc-pack.json
# Each loader returns a list of components for the given MC and loader versions
{
  fabric = mcVersion: loaderVersion: [
    {
      uid = "net.fabricmc.intermediary";
      version = mcVersion;
      dependencyOnly = true;
    }
    {
      uid = "net.fabricmc.fabric-loader";
      version = loaderVersion;
    }
  ];

  quilt = mcVersion: loaderVersion: [
    {
      uid = "org.quiltmc.hashed";
      version = mcVersion;
      dependencyOnly = true;
    }
    {
      uid = "org.quiltmc.quilt-loader";
      version = loaderVersion;
    }
  ];

  forge = _: loaderVersion: [
    {
      uid = "net.minecraftforge";
      version = loaderVersion;
    }
  ];

  neoforge = _: loaderVersion: [
    {
      uid = "net.neoforged";
      version = loaderVersion;
    }
  ];
}
