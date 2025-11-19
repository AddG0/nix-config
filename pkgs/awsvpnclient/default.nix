# AWS VPN Client for NixOS
#
# Based on the work by Polarizedions: https://github.com/Polarizedions/aws-vpn-client-flake
# Original implementation adapted and integrated into this nix-config.
#
# This package provides the AWS VPN Client with SAML authentication support on NixOS.
{
  lib,
  pkgs,
  stdenv,
  fetchurl,
  buildFHSEnv,
  autoPatchelfHook,
  makeDesktopItem,
  libredirect,
  ...
}: let
  pname = "awsvpnclient";

  # Version information
  versionInfo = {
    version = "3.15.0";
    sha256 = "5cf3eb08de96821b0ad3d0c93174b2e308041d5490a3edb772dfd89a6d89d012";
  };

  srcUrl = versionInfo: "https://d20adtppz83p9s.cloudfront.net/GTK/${versionInfo.version}/awsvpnclient_amd64.deb";

  exePrefix = "/opt/awsvpnclient";
  debGuiExe = "${exePrefix}/AWS VPN Client";
  guiExe = "${exePrefix}/awsvpnclient";
  serviceExe = "${exePrefix}/Service/ACVC.GTK.Service";

  wrapExeWithRedirects = exe: ''
    wrapProgram "${exe}" \
        --set LD_PRELOAD "${libredirect}/lib/libredirect.so" \
        --set NIX_REDIRECTS "${
      lib.concatStringsSep ":"
      (map (redir: "${redir.dest}=${redir.src}") serviceRedirects)
    }"
  '';

  # https://github.com/BOPOHA/aws-rpm-packages/tree/d9df3adf679a7e0f04e13d493085b24dc80b9cc3
  patchPrefix = "https://raw.githubusercontent.com/BOPOHA/aws-rpm-packages/d9df3adf679a7e0f04e13d493085b24dc80b9cc3/awsvpnclient";
  patchInfos = [
    {
      url = "${patchPrefix}/acvc.gtk..deps.patch";
      sha256 = "sha256-z3FFNj/Pk6EDkhiysqG2OlH9sLGaxSXNMRd1hQlRmeE=";
    }
    {
      url = "${patchPrefix}/awsvpnclient.deps.patch";
      sha256 = "sha256-+8J3Tp5UzqW+80bTcdid3bmLhci1dTsDAf6RakfRcDw=";
    }
  ];

  fetchedPatches = map (patch:
    fetchurl {
      inherit (patch) url sha256;
    })
  patchInfos;

  serviceRedirects = [
    {
      src = "${pkgs.ps}/bin/ps";
      dest = "/bin/ps";
    }
    {
      src = "${pkgs.lsof}/bin/lsof";
      dest = "/usr/bin/lsof";
    }
    {
      src = "${pkgs.sysctl}/bin/sysctl";
      dest = "/sbin/sysctl";
    }
  ];

  mkDeb = versionInfo:
    stdenv.mkDerivation {
      pname = "${pname}-deb";
      inherit (versionInfo) version;

      src = fetchurl {
        url = srcUrl versionInfo;
        inherit (versionInfo) sha256;
      };

      nativeBuildInputs = [autoPatchelfHook pkgs.makeWrapper];

      unpackPhase = ''
        ${pkgs.dpkg}/bin/dpkg -x "$src" unpacked
        mkdir -p "$out"
        cp -r unpacked/* "$out/"
        addAutoPatchelfSearchPath "$out/${exePrefix}"
        addAutoPatchelfSearchPath "$out/${exePrefix}/Service"
        addAutoPatchelfSearchPath "$out/${exePrefix}/Service/Resources/openvpn"
      '';

      fixupPhase = ''
        # Workaround for missing compatibility of the SQL library, intentionally breaking the metrics agent
        # It will be unable to load the dynamic lib and will start, but with error message
        rm "$out/opt/awsvpnclient/SQLite.Interop.dll"

        # Apply source patches
        cd "$out/opt/awsvpnclient"
        ${lib.concatStringsSep "\n" (map (patch: ''
            cp ${patch} tmp.patch
            sed -i -E 's|([+-]{3}) (\")?/opt/awsvpnclient/|\1 \2./|g' tmp.patch
            patch -p1 < tmp.patch
            rm tmp.patch
          '')
          fetchedPatches)}
        cd "$out"

        # Rename to something more "linux-y"
        mv "$out/${debGuiExe}" "$out/${guiExe}"

        ${wrapExeWithRedirects "$out/${serviceExe}"}
      '';
    };

  mkServiceFHS = {
    versionInfo,
    deb,
  }: let
    # Wrapper script that sets up writable Service directory while keeping Service/Resources read-only
    serviceWrapper = pkgs.writeShellScript "awsvpnclient-service-wrapper" ''
      set -e

      # Create writable directories
      mkdir -p /opt/awsvpnclient/Service/Resources/openvpn
      mkdir -p /opt/awsvpnclient/Resources

      # Copy Service files to writable location if not already done (excluding Resources which is bind-mounted)
      if [ ! -f "/opt/awsvpnclient/Service/ACVC.GTK.Service" ]; then
        echo "Initializing AWS VPN Client Service directory..."
        # Copy all files except Resources directory
        cd ${deb}/opt/awsvpnclient/Service
        for item in *; do
          if [ "$item" != "Resources" ]; then
            cp -a "$item" /opt/awsvpnclient/Service/
          fi
        done
        # Make copied files writable (excluding Resources which is read-only bind mount)
        cd /opt/awsvpnclient/Service
        for item in *; do
          if [ "$item" != "Resources" ]; then
            chmod -R u+w "$item"
          fi
        done
      fi

      # Run the service from writable location
      cd /opt/awsvpnclient/Service
      exec ./ACVC.GTK.Service
    '';

    ipBin = pkgs.writeShellScript "fix_aws_ip_call.sh" ''
      args=("$@")
      arg1=''${args[0]}
      arg2=''${args[1]}
      arg3=''${args[2]}
      arg4=''${args[3]}
      arg5=''${args[4]}
      arg6=''${args[5]}

      # expected args: 'addr' 'add' 'dev' 'tun0' <ip> 'broadcast' <ip>
      # if 'broadcast' is missing, calculate it
      if [ "$arg1" = 'addr' ] && [ "$arg2" = 'add' ] && [ "$arg3" = 'dev' ] && [ "$arg4" = 'tun0' ] && [ -z "$arg6" ]; then
        export $(${pkgs.ipcalc}/bin/ipcalc $arg5 -b)
        ${pkgs.iproute2}/bin/ip "''${args[@]}" broadcast $BROADCAST
      else
        ${pkgs.iproute2}/bin/ip "$@"
      fi
    '';

    # Patched configure-dns script with explicit bash shebang
    configureDnsScript = pkgs.runCommand "configure-dns-patched" {} ''
      cp ${deb}/opt/awsvpnclient/Service/Resources/openvpn/configure-dns $out
      chmod +w $out
      # Replace #!/usr/bin/env bash with explicit bash path
      sed -i '1s|^#!/usr/bin/env bash|#!/bin/bash|' $out
      chmod +x $out
    '';
  in
    buildFHSEnv {
      name = "${pname}-service-wrapped";
      inherit (versionInfo) version;

      runScript = "${serviceWrapper}";
      targetPkgs = _: [deb pkgs.systemd pkgs.iproute2 pkgs.coreutils pkgs.bash];

      extraBwrapArgs = [
        # Make /opt writable
        "--tmpfs /opt"
        # Create the Service/Resources/openvpn directory structure
        "--tmpfs /opt/awsvpnclient/Service/Resources"
        # Bind openvpn binary
        "--ro-bind ${deb}/opt/awsvpnclient/Service/Resources/openvpn/acvc-openvpn /opt/awsvpnclient/Service/Resources/openvpn/acvc-openvpn"
        # Bind our patched configure-dns script
        "--ro-bind ${configureDnsScript} /opt/awsvpnclient/Service/Resources/openvpn/configure-dns"
        # Also bind the top-level awsvpnclient contents
        "--ro-bind ${deb}/opt/awsvpnclient/awsvpnclient /opt/awsvpnclient/awsvpnclient"

        # For some reason, I can't do this with the redirect as I did above
        "--tmpfs /usr/sbin"
        "--ro-bind ${ipBin} /usr/sbin/ip"
      ];

      multiPkgs = _: with pkgs; [openssl_1_1 icu70];
    };

  mkDesktopItem = {
    versionInfo,
  }: (makeDesktopItem {
    name = pname;
    desktopName = "AWS VPN Client";
    exec = "${(guiFHS versionInfo).name} %u";
    icon = "awsvpnclient";
    categories = ["Network" "X-VPN"];
    startupWMClass = "awsvpnclient";
  });

  guiFHS = versionInfo: let
    deb = mkDeb versionInfo;
    serviceFHS = mkServiceFHS {inherit versionInfo deb;};
    desktopItem = mkDesktopItem {inherit versionInfo deb;};
  in
    buildFHSEnv {
      name = "${pname}-wrapped";
      inherit (versionInfo) version;

      runScript = "${guiExe}";
      targetPkgs = _: [deb];

      multiPkgs = _: with pkgs; [openssl_1_1 icu70 gtk3];

      extraInstallCommands = ''
        mkdir -p "$out/lib/systemd/system"
        cat <<EOF > "$out/lib/systemd/system/AwsVpnClientService.service"
        [Service]
        Type=simple
        ExecStart=${serviceFHS}/bin/${serviceFHS.name}
        Restart=always
        RestartSec=1s
        User=root

        [Install]
        WantedBy=multi-user.target
        EOF

        mkdir -p "$out/share/applications"
        cp "${desktopItem}/share/applications/${pname}.desktop" "$out/share/applications/${pname}.desktop"

        # Install icon to standard location
        mkdir -p "$out/share/pixmaps"
        cp "${deb}/usr/share/pixmaps/acvc-64.png" "$out/share/pixmaps/awsvpnclient.png"
      '';
    };

  # Why do I gotta make my own thing? .override doesn't work!?
  makeOverridable = f: origArgs: let
    origRes = f origArgs;
  in
    origRes // {overrideVersion = newArgs: (f (origArgs // newArgs));};
in
  makeOverridable guiFHS versionInfo
