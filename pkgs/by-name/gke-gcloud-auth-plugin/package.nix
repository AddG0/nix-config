{pkgs}:
pkgs.buildGo127Module rec {
  pname = "gke-gcloud-auth-plugin";
  version = "37.2.16";

  src = pkgs.fetchFromGitHub {
    owner = "kubernetes";
    repo = "cloud-provider-gcp";
    rev = "v${version}";
    sha256 = "sha256-TmdlbxN05gac8wXvBo+RE+PrmaOTIhEvV3twb1cJOkk=";
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
