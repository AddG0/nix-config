{inputs, ...}: {
  imports = [
    "${inputs.ai-toolkit}/host"
  ];

  ai-toolkit = {
    enable = true;
    neo4j.enable = true;
  };
}
