{
  pkgs,
  config,
  ...
}: {
  programs.zen-browser.profiles.default = rec {
    extensions.packages = with pkgs.firefox-addons; [
      pay-by-privacy # Privacy.com virtual cards
      leechblock-ng # Block time-wasting sites (youtube, reddit, etc) with time limits
    ];

    containersForce = true;
    containers = {
      Personal = {
        color = "purple";
        icon = "fingerprint";
        id = 1;
      };
      Work = {
        color = "blue";
        icon = "briefcase";
        id = 2;
      };
    };

    spacesForce = true;
    pinsForce = true;
    # NOTE: container must be set explicitly on each pin to match the workspace's container.
    # zenDefaultUserContextId doesn't reliably assign containers during session restore,
    # causing pins to be invisible in the sidebar.
    pins = {
      # Personal (Main workspace)
      "YouTube" = {
        id = "c02f1740-1a97-41bc-b843-d54651be4e43";
        url = "https://www.youtube.com";
        position = 1000;
        isEssential = true;
        workspace = spaces."Main".id;
        container = containers."Personal".id;
      };
      "Gmail" = {
        id = "a654602c-37c8-4ae4-aca0-11d2450c7367";
        url = "https://mail.google.com";
        position = 2000;
        isEssential = true;
        workspace = spaces."Main".id;
        container = containers."Personal".id;
      };
      "Google Calendar" = {
        id = "98ae1f6b-f9e9-4820-b3e3-17d09244a482";
        url = "https://calendar.google.com";
        position = 3000;
        isEssential = true;
        workspace = spaces."Main".id;
        container = containers."Personal".id;
      };
      "Home Assistant" = {
        id = "e9509332-f744-4346-b83a-571592a064c1";
        url = "https://home-assistant.addg0.com";
        position = 6000;
        workspace = spaces."Main".id;
        container = containers."Personal".id;
      };
      "UniFi" = {
        id = "b3f8a1d2-7c4e-4f9a-a5b6-2d1e0f3c8b7a";
        url = "https://unifi.ui.com";
        position = 7000;
        workspace = spaces."Main".id;
        container = containers."Personal".id;
      };
      "LLM Arena" = {
        id = "22ec3ca8-4c26-45da-93f4-e7ec675f89d6";
        url = "https://arena.ai/leaderboard/text/coding";
        position = 8000;
        workspace = spaces."Main".id;
        container = containers."Personal".id;
      };
      "GitLab Groups" = {
        id = "fd6f90e2-1f93-4c76-87f1-7c9f4de63f43";
        url = "https://gitlab.com/${config.hostSpec.primaryUsername}09";
        position = 9000;
        workspace = spaces."Main".id;
        container = containers."Personal".id;
      };
      "GitHub" = {
        id = "535f283d-2667-4f4c-9376-327baeda765d";
        url = "https://github.com";
        position = 10000;
        workspace = spaces."Main".id;
        container = containers."Personal".id;
      };
      "Monarch" = {
        id = "0b5c976f-4993-44e8-9aff-1c02991a2d41";
        url = "https://app.monarch.com";
        position = 11000;
        workspace = spaces."Main".id;
        container = containers."Personal".id;
      };
      # Work workspace
      "Gmail (Work)" = {
        id = "6003d95b-8446-478e-8a2f-098ec81df105";
        url = "https://mail.google.com";
        position = 2000;
        isEssential = true;
        workspace = spaces."Work".id;
        container = containers."Work".id;
      };
      "Google Calendar (Work)" = {
        id = "a767a013-531f-40c7-8f79-47ec3d10bf15";
        url = "https://calendar.google.com";
        position = 3000;
        isEssential = true;
        workspace = spaces."Work".id;
        container = containers."Work".id;
      };
      "JIRA" = {
        id = "1de5232d-c7cf-4c20-ac7f-62362ea4fa16";
        url = "https://webshopapps.atlassian.net/jira/software/c/projects/ENG26/boards/192?assignee=62b03e83566f3e7b0a8df8f8";
        position = 4000;
        workspace = spaces."Work".id;
        container = containers."Work".id;
      };
      "JIRA Dashboard" = {
        id = "29fd347a-68fb-4679-9162-0e6ba8c9cc42";
        url = "https://webshopapps.atlassian.net/jira/dashboards/10340?assignee=62b03e83566f3e7b0a8df8f8";
        position = 5000;
        workspace = spaces."Work".id;
        container = containers."Work".id;
      };
      "Confluence" = {
        id = "fce88b21-c084-4bb0-a685-bea7ebc690d1";
        url = "https://webshopapps.atlassian.net/wiki/spaces/ShipperHQ1/overview";
        position = 6000;
        workspace = spaces."Work".id;
        container = containers."Work".id;
      };
      "GitLab" = {
        id = "00427b2d-242d-4fa2-8b92-08f76b23bbc3";
        url = "https://gitlab.com/ShipperHQ";
        position = 7000;
        workspace = spaces."Work".id;
        container = containers."Work".id;
      };
      "Google Drive" = {
        id = "e24b14d3-5057-46ee-954e-0a515c0286ea";
        url = "https://drive.google.com/drive/u/0/folders/1MUa6UZl7c-x0fRSpXJi_oQnJjvIZSNEm";
        position = 8000;
        workspace = spaces."Work".id;
        container = containers."Work".id;
      };
      "ClickUp" = {
        id = "79f7ae43-e4cd-4ff7-9571-c9fef8e05b37";
        url = "https://app.clickup.com/90141311281/my-work/tasks";
        position = 8500;
        workspace = spaces."Work".id;
        container = containers."Work".id;
      };
    };

    # Icons: chrome://browser/skin/zen-icons/selectable/{name}.svg
    # Full list: unzip -l $(nix eval .#nixosConfigurations.demon.config.home-manager.users.addg.programs.zen-browser.package --raw)/lib/zen/browser/omni.ja | grep selectable
    spaces = {
      "Main" = {
        id = "a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d";
        icon = "chrome://browser/skin/zen-icons/selectable/star.svg";
        position = 1000;
        container = containers."Personal".id;
      };
      "Work" = {
        id = "f6e5d4c3-b2a1-4987-6543-210fedcba987";
        icon = "chrome://browser/skin/zen-icons/selectable/briefcase.svg";
        position = 2000;
        container = containers."Work".id;
      };
    };
  };
}
