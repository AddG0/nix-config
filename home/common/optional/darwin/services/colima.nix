_: {
  services.colima = {
    enable = true;
    profiles.default = {
      isActive = true;
      isService = true;
      setDockerHost = true;
      settings = {
        cpu = 4;
        memory = 8;
        disk = 100;
        arch = "host";
        runtime = "docker";
        # Apple Virtualization Framework — faster than qemu on Apple Silicon
        vmType = "vz";
        # x86_64 emulation via Rosetta for aarch64 hosts
        rosetta = true;
        # virtiofs is the fastest mount type when using vz
        mountType = "virtiofs";
      };
    };
  };
}
