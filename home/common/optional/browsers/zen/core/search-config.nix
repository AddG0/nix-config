{pkgs, ...}: {
  force = true;
  default = "google";
  privateDefault = "ddg";
  engines = let
    nixSnowflakeIcon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
  in {
    "Nix Packages" = {
      urls = [
        {
          template = "https://search.nixos.org/packages";
          params = [
            {
              name = "type";
              value = "packages";
            }
            {
              name = "channel";
              value = "unstable";
            }
            {
              name = "query";
              value = "{searchTerms}";
            }
          ];
        }
      ];
      icon = nixSnowflakeIcon;
      definedAliases = ["@pkgs"];
    };
    "Nix Options" = {
      urls = [
        {
          template = "https://search.nixos.org/options";
          params = [
            {
              name = "channel";
              value = "unstable";
            }
            {
              name = "query";
              value = "{searchTerms}";
            }
          ];
        }
      ];
      icon = nixSnowflakeIcon;
      definedAliases = ["@nop"];
    };
    "Home Manager Options" = {
      urls = [
        {
          template = "https://home-manager-options.extranix.com/";
          params = [
            {
              name = "query";
              value = "{searchTerms}";
            }
            {
              name = "release";
              value = "master";
            }
          ];
        }
      ];
      icon = nixSnowflakeIcon;
      definedAliases = ["@hmop"];
    };
    "ChatGPT" = {
      urls = [
        {
          template = "https://chat.openai.com";
          params = [
            {
              name = "q";
              value = "{searchTerms}";
            }
          ];
        }
      ];
      icon = "https://chatgpt.com/cdn/assets/favicon-eex17e9e.ico";
      definedAliases = ["@gpt" "@chatgpt"];
    };
    "GitHub" = {
      urls = [
        {
          template = "https://github.com/search";
          params = [
            {
              name = "q";
              value = "{searchTerms}";
            }
          ];
        }
      ];
      definedAliases = ["@gh" "@github"];
    };

    bing.metaData.hidden = "true";
  };
}
