{pkgs}:
pkgs.buildGo127Module rec {
  pname = "gke-gcloud-auth-plugin";
  version = "37.2.3";

  src = pkgs.fetchFromGitHub {
    owner = "kubernetes";
    repo = "cloud-provider-gcp";
    rev = "v${version}";
    sha256 = "sha256-Nfg9CXqXO17q0hEr1jTDMiI50qmBeYhBSqiv/cboFs0=";
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
