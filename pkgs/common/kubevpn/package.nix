{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule rec {
  pname = "kubevpn";
  version = "2.7.8";

  src = fetchFromGitHub {
    owner = "KubeNetworks";
    repo = "kubevpn";
    rev = "v${version}";
    hash = "sha256-T5mYB2eygH60MrJmwY90K0NwVEnPcYxMOTFZWxnSbAo=";
  };

  vendorHash = null;

  # TODO investigate why some config tests are failing
  doCheck = false;

  meta = with lib; {
    changelog = "https://github.com/KubeNetworks/kubevpn/releases/tag/${src.rev}";
    description = "Create a VPN and connect to Kubernetes cluster network, access resources, and more";
    homepage = "https://github.com/KubeNetworks/kubevpn";
    license = licenses.mit;
  };
}
