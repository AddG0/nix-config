{pkgs, ...}: {
  extensions = [
    pkgs.vscode-marketplace.esbenp.prettier-vscode
    pkgs.vscode-marketplace.foxundermoon.shell-format
  ];
  userSettings = {
    "prettier.enable" = true;
    "[javascript]" = {
      "editor.defaultFormatter" = "esbenp.prettier-vscode";
    };
    "[javascriptreact]" = {
      "editor.defaultFormatter" = "esbenp.prettier-vscode";
    };
    "[typescript]" = {
      "editor.defaultFormatter" = "esbenp.prettier-vscode";
    };
    "[typescriptreact]" = {
      "editor.defaultFormatter" = "esbenp.prettier-vscode";
    };
    "[json]" = {
      "editor.defaultFormatter" = "esbenp.prettier-vscode";
    };
    "[html]" = {
      "editor.defaultFormatter" = "esbenp.prettier-vscode";
    };
    "[css]" = {
      "editor.defaultFormatter" = "esbenp.prettier-vscode";
    };

    # shfmt-based shell formatter; respects .editorconfig to match treefmt
    "shellformat.path" = "${pkgs.shfmt}/bin/shfmt";
    "shellformat.useEditorConfig" = true;
    "[shellscript]" = {
      "editor.defaultFormatter" = "foxundermoon.shell-format";
    };
    "[dockerfile]" = {
      "editor.defaultFormatter" = "foxundermoon.shell-format";
    };
    "[ignore]" = {
      "editor.defaultFormatter" = "foxundermoon.shell-format";
    };
    "[dotenv]" = {
      "editor.defaultFormatter" = "foxundermoon.shell-format";
    };
  };
}
