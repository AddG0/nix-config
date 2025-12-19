{pkgs, ...}: {
  extensions = [
    pkgs.vscode-marketplace.jnoortheen.nix-ide
  ];
  userSettings = {
    "nix.enableLanguageServer" = true;
    "nix.serverPath" = "${pkgs.nixd}/bin/nixd";
    "nix.serverSettings" = {
      "nixd" = {
        "formatting" = {
          "command" = ["${pkgs.alejandra}/bin/alejandra"];
        };
      };
    };
  };
  languageSnippets = {
    nix = {
      "mkDerivation" = {
        prefix = "mkd";
        body = [
          "{ lib, stdenv }:"
          ""
          "stdenv.mkDerivation rec {"
          "  pname = \"\${1:name}\";"
          "  version = \"\${2:0.1.0}\";"
          ""
          "  src = \${3:./src};"
          ""
          "  buildInputs = [ \${4} ];"
          ""
          "  meta = with lib; {"
          "    description = \"\${5:Description}\";"
          "    license = licenses.\${6:mit};"
          "  };"
          "}"
        ];
        description = "Create a stdenv.mkDerivation";
      };
      "mkOption" = {
        prefix = "mko";
        body = [
          "\${1:optionName} = lib.mkOption {"
          "  type = lib.types.\${2:str};"
          "  default = \${3:null};"
          "  description = \"\${4:Description}\";"
          "};"
        ];
        description = "Create a lib.mkOption";
      };
      "mkEnableOption" = {
        prefix = "mke";
        body = [
          "enable = lib.mkEnableOption \"\${1:feature name}\";"
        ];
        description = "Create a lib.mkEnableOption";
      };
      "mkIf" = {
        prefix = "mki";
        body = [
          "lib.mkIf config.\${1:option}.enable {"
          "  \${2}"
          "}"
        ];
        description = "Create a lib.mkIf block";
      };
      "let-in" = {
        prefix = "let";
        body = [
          "let"
          "  \${1:name} = \${2:value};"
          "in"
          "\${3}"
        ];
        description = "Create a let-in block";
      };
      "module" = {
        prefix = "mod";
        body = [
          "{ config, lib, pkgs, ... }:"
          ""
          "let"
          "  cfg = config.\${1:services.myservice};"
          "in {"
          "  options.\${1:services.myservice} = {"
          "    enable = lib.mkEnableOption \"\${2:my service}\";"
          "  };"
          ""
          "  config = lib.mkIf cfg.enable {"
          "    \${3}"
          "  };"
          "}"
        ];
        description = "Create a NixOS/home-manager module";
      };
      "flake" = {
        prefix = "flake";
        body = [
          "{"
          "  description = \"\${1:A Nix flake}\";"
          ""
          "  inputs = {"
          "    nixpkgs.url = \"github:NixOS/nixpkgs/nixos-unstable\";"
          "  };"
          ""
          "  outputs = { self, nixpkgs }: {"
          "    \${2}"
          "  };"
          "}"
        ];
        description = "Create a flake.nix template";
      };
    };
  };
}
