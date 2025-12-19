# Completions for kind-start command
def "nu-complete kind-start clusters" [] {
    # Only show stopped clusters
    docker ps -a --filter "label=io.x-k8s.kind.cluster" --filter "status=exited" --format '{{.Label "io.x-k8s.kind.cluster"}}'
    | lines
    | uniq
    | sort
}

export extern "kind-start" [
    cluster?: string@"nu-complete kind-start clusters"  # Cluster name to start
    --help(-h)                                          # Show help
]
