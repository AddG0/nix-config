{inputs, ...}: {
  imports = [
    inputs.ai-toolkit.nixosModules.ai-toolkit
  ];

  ai-toolkit = {
    enable = true;
    neo4j.enable = true;
  };
}
