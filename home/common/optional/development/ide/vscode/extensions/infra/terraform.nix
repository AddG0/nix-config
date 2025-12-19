{pkgs, ...}: {
  extensions = [
    pkgs.vscode-marketplace.hashicorp.terraform
  ];
  userSettings = {
    "terraform.languageServer.enable" = true;
    "terraform.languageServer.path" = "${pkgs.terraform-ls}/bin/terraform-ls";
    "terraform.experimentalFeatures.validateOnSave" = true;
    "terraform.experimentalFeatures.prefillRequiredFields" = true;
    "[terraform]" = {
      "editor.defaultFormatter" = "hashicorp.terraform";
      "editor.formatOnSave" = true;
    };
    "[terraform-vars]" = {
      "editor.defaultFormatter" = "hashicorp.terraform";
      "editor.formatOnSave" = true;
    };
  };
}
