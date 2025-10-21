{pkgs}:
pkgs.buildGoModule rec {
  pname = "gke-gcloud-auth-plugin";
  version = "34.0.0";

  src = pkgs.fetchFromGitHub {
    owner = "kubernetes";
    repo = "cloud-provider-gcp";
    rev = "ccm/v${version}";
    sha256 = "sha256-35ANmQmv2xrN/gemP5peNcaEUnaVbGk35KtviBHfNsc=";
  };

  modRoot = "./cmd/gke-gcloud-auth-plugin";

  vendorHash = null;

  ldflags = [
    "-s"
    "-w"
  ];

  meta = with pkgs.lib; {
    description = "GKE gcloud authentication plugin for kubectl";
    homepage = "https://github.com/kubernetes/cloud-provider-gcp";
    license = licenses.asl20;
  };
}
