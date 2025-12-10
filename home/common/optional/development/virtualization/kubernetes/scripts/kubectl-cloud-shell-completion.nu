# Nushell completion for kubectl-cloud-shell
# This provides completions for the custom kubectl-cloud-shell command

module completions {

  # Get kubectl contexts for completion
  def "nu-complete kubectl-contexts" [] {
    kubectl config get-contexts -o name | lines
  }

  # Get kubectl namespaces for completion
  def "nu-complete kubectl-namespaces" [] {
    kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' | split row ' '
  }

  # Main completion for kubectl-cloud-shell
  export extern "kubectl-cloud-shell" [
    --bare                           # Use bare mode with minimal zsh setup instead of home-manager
    --namespace(-n): string@"nu-complete kubectl-namespaces"  # Kubernetes namespace
    --context: string@"nu-complete kubectl-contexts"          # Kubernetes context to use
    --kubeconfig: path                                        # Path to kubeconfig file
    --cluster: string                                         # Kubernetes cluster to use
    --user: string                                            # Kubernetes user to use
    --as: string                                              # Username to impersonate
    --as-group: string                                        # Group to impersonate
    --as-uid: string                                          # UID to impersonate
    --cache-dir: path                                         # Default cache directory
    --certificate-authority: path                             # Path to cert file for certificate authority
    --client-certificate: path                                # Path to client certificate file
    --client-key: path                                        # Path to client key file
    --insecure-skip-tls-verify                                # Skip TLS certificate verification
    --request-timeout: string                                 # Request timeout (e.g., '0' for infinite)
    --server(-s): string                                      # Kubernetes API server address
    --tls-server-name: string                                 # Server name for TLS validation
    --token: string                                           # Bearer token for authentication
    -v: int                                                   # Log level verbosity
  ]

}

export use completions *
