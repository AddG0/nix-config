# gitlab.nvim — review and manage GitLab MRs inside Neovim.
#
# Upstream normally compiles its Go server on first launch; that won't work in
# Nix. Instead we build the server here and point the plugin at it via
# `settings.server.binary` (see home/common/core/nixvim/gitlab-mr.nix), which
# upstream treats as a user-provided binary and never tries to rebuild.
{
  lib,
  buildGoModule,
  vimUtils,
  fetchFromGitHub,
}: let
  pname = "gitlab-nvim";
  version = "4.1.1";
  rev = "2295d1e85c5e4d79c49cadda36b9848a3ffed4e2";

  src = fetchFromGitHub {
    owner = "harrisoncramer";
    repo = "gitlab.nvim";
    inherit rev;
    hash = "sha256-J2yljPEWjFQf5XOm1VwlZSqvVhP4VO/k9nrzdmXEMG0=";
  };

  server = buildGoModule {
    pname = "${pname}-server";
    inherit version src;
    vendorHash = "sha256-OLAKTdzqynBDHqWV5RzIpfc3xZDm6uYyLD4rxbh0DMg=";
    subPackages = ["cmd"];
    ldflags = ["-s" "-w" "-X main.Version=${rev}"];
    postInstall = ''
      mv "$out/bin/cmd" "$out/bin/gitlab-nvim-server"
    '';
    meta.mainProgram = "gitlab-nvim-server";
  };
in
  vimUtils.buildVimPlugin {
    inherit pname version src;

    # Modules load lazily and several require the running Go server, so the
    # import-time require check can't exercise them headlessly.
    doCheck = false;

    passthru = {inherit server;};

    meta = {
      description = "Review and manage GitLab MRs inside Neovim";
      homepage = "https://github.com/harrisoncramer/gitlab.nvim";
      license = lib.licenses.mit;
    };
  }
