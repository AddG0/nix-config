#!/usr/bin/env bash
# Start a kind cluster and restore its kubeconfig

set -euo pipefail

show_help() {
	echo "Usage: kind-start [CLUSTER_NAME]"
	echo ""
	echo "Start a kind cluster and export its kubeconfig."
	echo "If no cluster name is provided, lists available clusters."
	echo ""
	echo "Examples:"
	echo "  kind-start           # List clusters and start interactively"
	echo "  kind-start kind      # Start cluster named 'kind'"
	echo "  kind-start my-cluster"
}

list_stopped_clusters() {
	# Get stopped kind clusters (exited state)
	docker ps -a --filter "label=io.x-k8s.kind.cluster" --filter "status=exited" --format '{{.Label "io.x-k8s.kind.cluster"}}' | sort -u
}

list_all_clusters() {
	# Get all kind clusters
	docker ps -a --filter "label=io.x-k8s.kind.cluster" --format '{{.Label "io.x-k8s.kind.cluster"}}' | sort -u
}

start_cluster() {
	local cluster_name="$1"

	echo "Starting kind cluster: $cluster_name"

	# Find stopped containers for this cluster
	local containers
	containers=$(docker ps -a --filter "label=io.x-k8s.kind.cluster=$cluster_name" --filter "status=exited" --format '{{.Names}}')

	if [[ -z $containers ]]; then
		# Check if cluster exists but is already running
		local running
		running=$(docker ps --filter "label=io.x-k8s.kind.cluster=$cluster_name" --format '{{.Names}}')
		if [[ -n $running ]]; then
			echo "Cluster '$cluster_name' is already running"
			echo "Exporting kubeconfig..."
			kind export kubeconfig --name "$cluster_name"
			echo "✓ Kubeconfig exported for '$cluster_name'"
			exit 0
		fi
		echo "Error: No containers found for cluster '$cluster_name'"
		echo "Available clusters:"
		list_all_clusters
		exit 1
	fi

	# Start the containers
	echo "$containers" | xargs docker start

	# Wait for the API server to be ready
	echo "Waiting for cluster to be ready..."
	sleep 3

	# Export kubeconfig
	echo "Exporting kubeconfig..."
	kind export kubeconfig --name "$cluster_name"

	echo ""
	echo "✓ Cluster '$cluster_name' started and kubeconfig exported"
	kubectl cluster-info --context "kind-$cluster_name" 2>/dev/null || true
}

# Main
if [[ ${1:-} == "-h" ]] || [[ ${1:-} == "--help" ]]; then
	show_help
	exit 0
fi

if [[ -n ${1:-} ]]; then
	# Cluster name provided
	start_cluster "$1"
else
	# No cluster name - list stopped clusters
	clusters=$(list_stopped_clusters)

	if [[ -z $clusters ]]; then
		# Check if there are any clusters at all
		all_clusters=$(list_all_clusters)
		if [[ -z $all_clusters ]]; then
			echo "No kind clusters found."
			echo "Create one with: kind create cluster"
		else
			echo "All kind clusters are already running."
		fi
		exit 0
	fi

	cluster_count=$(echo "$clusters" | wc -l)

	if [[ $cluster_count -eq 1 ]]; then
		# Only one cluster, start it directly
		start_cluster "$clusters"
	else
		# Multiple clusters, let user choose
		echo "Available kind clusters:"
		echo "$clusters" | nl -w2 -s') '
		echo ""
		read -rp "Enter cluster name or number: " choice

		# Check if choice is a number
		if [[ $choice =~ ^[0-9]+$ ]]; then
			selected=$(echo "$clusters" | sed -n "${choice}p")
		else
			selected="$choice"
		fi

		if [[ -n $selected ]]; then
			start_cluster "$selected"
		else
			echo "Invalid selection"
			exit 1
		fi
	fi
fi
