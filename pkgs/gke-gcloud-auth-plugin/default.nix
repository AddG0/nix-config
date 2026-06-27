{pkgs}:
pkgs.buildGoModule rec {
  pname = "gke-gcloud-auth-plugin";
  version = "36.1.8";

  src = pkgs.fetchFromGitHub {
    owner = "kubernetes";
    repo = "cloud-provider-gcp";
    rev = "v${version}";
    sha256 = "sha256-V5HrFFouiTE0IBJrbb4/pNfTmLIPVo4a9kjrrhoJjDE=";
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
