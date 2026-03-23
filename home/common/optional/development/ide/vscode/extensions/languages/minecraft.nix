{pkgs, ...}: {
  userSettings = {
    "[snbt]" = {
      "editor.defaultFormatter" = "Tnze.snbt";
    };
  };

  extensions = with pkgs.vscode-marketplace; [
    tnze.snbt # SNBT syntax highlighting
    spgoding.datapack-language-server # Datapack Helper Plus - command autocomplete, diagnostics
    chencmd.mc-datapack-utility # Datapack utility features
    hujohner.mc-datapack # Datapack creation helper
    exatom.better-datapack # Datapack quality-of-life tweaks
    minecraftcommands.syntax-mcfunction # mcfunction syntax highlighting (required by Spyglass)
  ];
}
