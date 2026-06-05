{pkgs}:
pkgs.buildGoModule rec {
  pname = "gke-gcloud-auth-plugin";
  version = "36.0.14";

  src = pkgs.fetchFromGitHub {
    owner = "kubernetes";
    repo = "cloud-provider-gcp";
    rev = "v${version}";
    sha256 = "sha256-x+ItR6OvF4HitT3pYkuCcHxN+v+4w8m/JZ1ddkeXRvA=";
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
