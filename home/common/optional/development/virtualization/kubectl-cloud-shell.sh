# Check for --bare flag
BARE_MODE=false
KUBECTL_ARGS=()

for arg in "$@"; do
  if [ "$arg" = "--bare" ]; then
    BARE_MODE=true
  else
    KUBECTL_ARGS+=("$arg")
  fi
done

# Generate unique pod name
POD_NAME="nix-cloud-shell-$(date +%s)"

# Create pod manifest
cat <<EOF | kubectl "${KUBECTL_ARGS[@]}" apply -f -
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

          # Enable flakes and nix-command
          mkdir -p ~/.config/nix
          {
            echo "experimental-features = nix-command flakes"
            echo "accept-flake-config = true"
          } > ~/.config/nix/nix.conf

          if [ "$BARE_MODE" = "true" ]; then
            # Bare mode - nix with zsh and oh-my-zsh, no home-manager
            echo "====================================="
            echo "Bare Nix Shell (zsh + oh-my-zsh)"
            echo "====================================="

            # Install zsh and oh-my-zsh using nix profile
            # Note: glibc provides iconv command needed by oh-my-zsh
            nix profile install nixpkgs#zsh nixpkgs#oh-my-zsh nixpkgs#glibc nixpkgs#coreutils

            # Set up minimal zshrc with oh-my-zsh
            echo 'export ZSH=\$HOME/.nix-profile/share/oh-my-zsh' > ~/.zshrc
            echo 'ZSH_THEME="robbyrussell"' >> ~/.zshrc
            echo 'plugins=(git)' >> ~/.zshrc
            echo 'source \$ZSH/oh-my-zsh.sh' >> ~/.zshrc

            cd "\$HOME"

            # Add nix profile to PATH and start zsh
            export PATH="\$HOME/.nix-profile/bin:\$PATH"
            exec zsh
          else
            # Full mode with home-manager
            mkdir -p ~/.local/state/nix/profiles

            echo "Activating cloud-shell home-manager configuration..."
            nix run home-manager/master -- switch --impure --flake "git+https://github.com/AddG0/nix-config?ref=main#cloud-shell" -b backup

            echo "====================================="
            echo "Welcome to cloud-shell environment!"
            echo "Configuration: AddG0/nix-config"
            echo "====================================="

            cd "\$HOME"
            exec env PATH="\$HOME/.nix-profile/bin:\$PATH" zsh -l
          fi
      stdin: true
      tty: true
      env:
        - name: HOME
          value: /home/addg
        - name: USER
          value: addg
        - name: BARE_MODE
          value: "$BARE_MODE"
EOF

echo "Waiting for pod $POD_NAME to be ready..."
kubectl "${KUBECTL_ARGS[@]}" wait --for=condition=Ready "pod/$POD_NAME" --timeout=120s

echo "Attaching to pod $POD_NAME..."
echo "Type 'exit' to leave the pod. The pod will be deleted automatically."

# Attach to the pod, and delete it when done
kubectl "${KUBECTL_ARGS[@]}" attach -it "$POD_NAME" || true

echo "Deleting pod $POD_NAME..."
kubectl "${KUBECTL_ARGS[@]}" delete pod "$POD_NAME" --wait=false
