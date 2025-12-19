#compdef kind-start

_kind-start() {
    local -a clusters already_provided

    # Get arguments already on the command line (excluding the command itself)
    already_provided=(${words[2,-1]})

    # Only show stopped clusters
    clusters=(${(f)"$(docker ps -a --filter 'label=io.x-k8s.kind.cluster' --filter 'status=exited' --format '{{.Label "io.x-k8s.kind.cluster"}}' 2>/dev/null | sort -u)"})

    # Remove already provided clusters from suggestions
    for arg in $already_provided; do
        clusters=(${clusters:#$arg})
    done

    if (( ${#clusters} > 0 )); then
        _describe 'stopped kind clusters' clusters
    fi
}

_kind-start "$@"
