{pkgs, ...}: {
  extensions = [
    pkgs.vscode-marketplace.postman.postman-for-vscode
  ];
  userSettings = {
    "postman.telemetry.enabled" = false;
    "postman.settings.dotenv-detection-notification-visibility" = false;
    "chat.instructionsFilesLocations" = {
      # Postman writes this back merged with VS Code's defaults, so they are pinned to make that write a no-op.
      ".github/instructions" = true;
      ".claude/rules" = true;
      "~/.copilot/instructions" = true;
      "~/.claude/rules" = true;
      "/tmp/postman-collections-post-response.instructions.md" = true;
      "/tmp/postman-collections-pre-request.instructions.md" = true;
      "/tmp/postman-folder-post-response.instructions.md" = true;
      "/tmp/postman-folder-pre-request.instructions.md" = true;
      "/tmp/postman-http-request-post-response.instructions.md" = true;
      "/tmp/postman-http-request-pre-request.instructions.md" = true;
    };
  };
}
