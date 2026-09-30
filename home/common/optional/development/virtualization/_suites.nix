{optional, ...}:
with optional.home.development.virtualization; {
  virtualization.home = [docker k9s kubernetes];
  docker.home = [docker];
}
