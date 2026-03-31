{pkgs}:
pkgs.buildGoModule rec {
  pname = "gke-gcloud-auth-plugin";
  version = "35.0.5";

  src = pkgs.fetchFromGitHub {
    owner = "kubernetes";
    repo = "cloud-provider-gcp";
    rev = "ccm/v${version}";
    sha256 = "sha256-dWpqmihUoD+bnT+uoobyvMc8vi8J8HHQqMDOpIRXqfU=";
  };

  modRoot = "./cmd/gke-gcloud-auth-plugin";

  vendorHash = null;

  ldflags = [
    "-s"
    "-w"
  ];

  passthru.updateScript = [ "nix-update" "--flake" "gke-gcloud-auth-plugin" "--version-regex" "ccm/v(.*)" ];

  meta = with pkgs.lib; {
    description = "GKE gcloud authentication plugin for kubectl";
    homepage = "https://github.com/kubernetes/cloud-provider-gcp";
    license = licenses.asl20;
  };
}
