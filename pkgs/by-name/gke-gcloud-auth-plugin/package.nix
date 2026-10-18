{pkgs}:
pkgs.buildGoModule rec {
  pname = "gke-gcloud-auth-plugin";
  version = "37.1.5";

  src = pkgs.fetchFromGitHub {
    owner = "kubernetes";
    repo = "cloud-provider-gcp";
    rev = "v${version}";
    sha256 = "sha256-lUvcQEwJmqKjGOQcGQYuAyxT5qO6haBBz4oN1oBBN28=";
  };

  modRoot = "./cmd/gke-gcloud-auth-plugin";

  vendorHash = null;

  ldflags = [
    "-s"
    "-w"
  ];

  passthru.updateScript = ["nix-update" "--flake" "gke-gcloud-auth-plugin" "--version-regex" "v(\\d.*)"];

  meta = with pkgs.lib; {
    description = "GKE gcloud authentication plugin for kubectl";
    homepage = "https://github.com/kubernetes/cloud-provider-gcp";
    license = licenses.asl20;
  };
}
