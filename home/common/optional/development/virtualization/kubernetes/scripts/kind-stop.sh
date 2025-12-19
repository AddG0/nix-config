#!/usr/bin/env bash
# Stop a kind cluster without deleting it

set -euo pipefail

show_help() {
	echo "Usage: kind-stop [CLUSTER_NAME]"
	echo ""
	echo "Stop a kind cluster (preserves data, can be restarted with kind-start)."
	echo "If no cluster name is provided, lists running clusters."
	echo ""
	echo "Examples:"
	echo "  kind-stop           # List running clusters and stop interactively"
	echo "  kind-stop kind      # Stop cluster named 'kind'"
}

list_running_clusters() {
	docker ps --filter "label=io.x-k8s.kind.cluster" --format '{{.Label "io.x-k8s.kind.cluster"}}' | sort -u
}

stop_cluster() {
	local cluster_name="$1"

	echo "Stopping kind cluster: $cluster_name"

	# Find all running containers for this cluster
	local containers
	containers=$(docker ps --filter "label=io.x-k8s.kind.cluster=$cluster_name" --format '{{.Names}}')

	if [[ -z $containers ]]; then
		echo "No running containers found for cluster '$cluster_name'"
		exit 0
	fi

	# Stop the containers
	echo "$containers" | xargs docker stop

	echo "✓ Cluster '$cluster_name' stopped"
	echo "  Restart with: kind-start $cluster_name"
}

# Main
if [[ ${1:-} == "-h" ]] || [[ ${1:-} == "--help" ]]; then
	show_help
	exit 0
fi

if [[ -n ${1:-} ]]; then
	stop_cluster "$1"
else
	clusters=$(list_running_clusters)

	if [[ -z $clusters ]]; then
		echo "No running kind clusters found."
		exit 0
	fi

	cluster_count=$(echo "$clusters" | wc -l)

	if [[ $cluster_count -eq 1 ]]; then
		stop_cluster "$clusters"
	else
		echo "Running kind clusters:"
		echo "$clusters" | nl -w2 -s') '
		echo ""
		read -rp "Enter cluster name or number: " choice

		if [[ $choice =~ ^[0-9]+$ ]]; then
			selected=$(echo "$clusters" | sed -n "${choice}p")
		else
			selected="$choice"
		fi

		if [[ -n $selected ]]; then
			stop_cluster "$selected"
		else
			echo "Invalid selection"
			exit 1
		fi
	fi
fi
