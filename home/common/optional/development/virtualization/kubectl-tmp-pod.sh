# Generate unique pod name
POD_NAME="nix-cloud-shell-$(date +%s)"

# Create pod manifest
cat <<EOF | kubectl "$@" apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: $POD_NAME
spec:
  restartPolicy: Never
  containers:
    - name: nix-shell
      image: nixos/nix:latest
      command:
        - bash
        - -c
        - |
          set -e

          # Enable flakes and nix-command, and accept flake config automatically
          mkdir -p ~/.config/nix
          {
            echo "experimental-features = nix-command flakes"
            echo "accept-flake-config = true"
          } > ~/.config/nix/nix.conf

          # Create necessary profile directories
          mkdir -p ~/.local/state/nix/profiles

          echo "Activating cloud-shell home-manager configuration..."
          nix run home-manager/master -- switch --flake "git+https://github.com/AddG0/nix-config?ref=main#cloud-shell" -b backup

          # Start an interactive shell
          echo "====================================="
          echo "Welcome to cloud-shell environment!"
          echo "Configuration: AddG0/nix-config"
          echo "====================================="
          exec bash
      stdin: true
      tty: true
      env:
        - name: HOME
          value: /home/addg
        - name: USER
          value: addg
EOF

echo "Waiting for pod $POD_NAME to be ready..."
kubectl "$@" wait --for=condition=Ready "pod/$POD_NAME" --timeout=120s

echo "Attaching to pod $POD_NAME..."
echo "Type 'exit' to leave the pod. The pod will be deleted automatically."

# Attach to the pod, and delete it when done
kubectl "$@" attach -it "$POD_NAME" || true

echo "Deleting pod $POD_NAME..."
kubectl "$@" delete pod "$POD_NAME" --wait=false
