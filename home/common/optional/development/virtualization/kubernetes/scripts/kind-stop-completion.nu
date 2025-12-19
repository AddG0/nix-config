# Completions for kind-stop command
def "nu-complete kind-stop clusters" [] {
    docker ps --filter "label=io.x-k8s.kind.cluster" --format '{{.Label "io.x-k8s.kind.cluster"}}'
    | lines
    | uniq
    | sort
}

export extern "kind-stop" [
    cluster?: string@"nu-complete kind-stop clusters"  # Cluster name to stop
    --help(-h)                                         # Show help
]
