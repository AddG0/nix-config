{
  lib,
  pkgs,
  ...
}: {
  assertions = [(lib.hm.assertions.assertPlatform "services.ollama" pkgs lib.platforms.darwin)];

  services.ollama = {
    enable = true;
    environmentVariables = {
      OLLAMA_FLASH_ATTENTION = "1";
      OLLAMA_CONTEXT_LENGTH = "65536";
    };
  };
}
