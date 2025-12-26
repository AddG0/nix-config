# Helper functions for Prism Launcher module
{lib}: let
  inherit (lib) hasAttr;
in {
  # Validate instance name (security: prevent path traversal and command injection)
  validateInstanceName = name:
    if builtins.match "[a-zA-Z0-9_.-]+" name == null
    then
      throw ''
        Invalid instance name: "${name}"
        Instance names must contain only alphanumeric characters, underscores, hyphens, or dots.
      ''
    else name;

  # Parse pack.toml to extract versions (with validation)
  parsePackToml = source: let
    packTomlPath = "${source}/pack.toml";

    content =
      if builtins.pathExists packTomlPath
      then builtins.readFile packTomlPath
      else throw "pack.toml not found at: ${packTomlPath}";

    parsed = let
      result = builtins.tryEval (builtins.fromTOML content);
    in
      if result.success
      then result.value
      else throw "Invalid TOML syntax in ${packTomlPath}";

    versions = parsed.versions or (throw "No [versions] section in ${packTomlPath}");

    # Detect loader from versions keys
    loaderName =
      if hasAttr "fabric" versions
      then "fabric"
      else if hasAttr "quilt" versions
      then "quilt"
      else if hasAttr "forge" versions
      then "forge"
      else if hasAttr "neoforge" versions
      then "neoforge"
      else throw "No supported loader (fabric/quilt/forge/neoforge) found in ${packTomlPath}";
  in {
    mcVersion = versions.minecraft or (throw "No minecraft version in ${packTomlPath}");
    loader = loaderName;
    loaderVersion = versions.${loaderName};
  };

  # Resolve icon - returns { key, path?, isCustom }
  # If icon is a path, we need to install it and use filename as key
  # If icon is a string, use it directly as the key
  resolveIcon = icon:
    if builtins.isPath icon || (builtins.isString icon && lib.hasPrefix "/" icon)
    then let
      iconPath =
        if builtins.isString icon
        then /. + icon
        else icon;
      filename = builtins.baseNameOf (toString iconPath);
      key = builtins.head (builtins.match "([^.]+).*" filename);
    in {
      inherit key;
      path = iconPath;
      isCustom = true;
    }
    else {
      key = icon;
      path = null;
      isCustom = false;
    };
}
