{pkgs}: {
  extensions = [
    pkgs.vscode-marketplace.ms-vsliveshare.vsliveshare
  ];
  userSettings = {
    "liveshare.guestApprovalRequired" = true;
    "liveshare.anonymousGuestApproval" = "reject";
  };
}
