# Build every user in hostSpec.users (system + home-manager) inline.
{
  inputs,
  pkgs,
  config,
  lib,
  ...
}: let
  inherit (config) hostSpec desktops;
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  platform =
    if isDarwin
    then "darwin"
    else "nixos";

  userDir = user:
    if user == hostSpec.primaryUsername
    then "primary"
    else user;

  genPubKeyList = user: let
    keyPath = lib.custom.relativeToRoot "hosts/common/users/${userDir user}/keys";
  in
    if lib.pathExists keyPath
    then lib.lists.forEach (lib.filesystem.listFilesRecursive keyPath) (key: builtins.readFile key)
    else [];
  superPubKeys = genPubKeyList "super";

  useSopsPassword = !hostSpec.disableSops && !hostSpec.isMinimal;

  fullPathIfExists = path: let
    full = lib.custom.relativeToRoot path;
  in
    lib.optional (lib.pathExists full) full;
in {
  programs.zsh.enable = true;
  environment.systemPackages = with pkgs; [just rsync home-manager];

  users.users = lib.mergeAttrsList (map (user: {
      ${user} = let
        platformPath = lib.custom.relativeToRoot "hosts/common/users/${userDir user}/${platform}.nix";
      in
        {
          name = user;
          shell = pkgs.zsh;
          home =
            if isDarwin
            then "/Users/${user}"
            else "/home/${user}";
          openssh.authorizedKeys.keys = (genPubKeyList user) ++ superPubKeys;
        }
        // (
          if isDarwin
          then {}
          else if user == hostSpec.primaryUsername && useSopsPassword
          then {hashedPasswordFile = config.sops.secrets."password".path;}
          else {initialPassword = "changeme";}
        )
        // lib.optionalAttrs (lib.pathExists platformPath) (import platformPath {inherit config lib;});
    })
    hostSpec.users);

  home-manager = {
    extraSpecialArgs = {
      inherit pkgs inputs hostSpec desktops;
      inherit (inputs) nix-secrets;
    };
    users = lib.mergeAttrsList (map (user: {
        ${user}.imports = lib.flatten [
          (lib.optional (!hostSpec.isMinimal) (map fullPathIfExists [
            "home/${userDir user}/${hostSpec.hostName}.nix"
            "home/${userDir user}/common/core"
            "home/common/core"
          ]))
          {
            programs.home-manager.enable = true;
            home = {
              stateVersion = hostSpec.system.stateVersion;
              username = user;
              homeDirectory =
                if isDarwin
                then "/Users/${user}"
                else "/home/${user}";
            };
          }
        ];
      })
      hostSpec.users);
  };
}
