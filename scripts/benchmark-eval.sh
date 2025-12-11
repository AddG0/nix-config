#!/usr/bin/env bash
# benchmark-eval.sh - Compare evaluation performance between branches
# Usage: ./benchmark-eval.sh <feature-branch> [base-branch] [hostname] [iterations]

set -e

if [ -z "$1" ]; then
	echo "❌ Error: Feature branch is required"
	echo "Usage: $0 <feature-branch> [base-branch] [hostname] [iterations]"
	echo ""
	echo "Examples:"
	echo "  $0 perf-optimizations                    # Compare perf-optimizations vs main on current host"
	echo "  $0 feature-x develop                     # Compare feature-x vs develop"
	echo "  $0 perf-optimizations main ghost 5       # Compare on specific host with 5 iterations"
	exit 1
fi

FEATURE_BRANCH="$1"
BASE_BRANCH="${2:-main}"
HOST="${3:-$(hostname)}"
ITERATIONS="${4:-3}"

# Detect OS and build flake path
if [ "$(uname -s)" = "Darwin" ]; then
	FLAKE_ATTR="darwinConfigurations.${HOST}.config.system.stateVersion"
	OS_TYPE="darwin"
else
	FLAKE_ATTR="nixosConfigurations.${HOST}.config.system.stateVersion"
	OS_TYPE="nixos"
fi

echo "🔬 Benchmarking Nix Evaluation Performance"
echo "=========================================="
echo "Feature Branch: $FEATURE_BRANCH"
echo "Base Branch:    $BASE_BRANCH"
echo "Host:           $HOST ($OS_TYPE)"
echo "Iterations:     $ITERATIONS"
echo ""

# Store current branch
CURRENT_BRANCH=$(git branch --show-current)

# Function to run benchmark
benchmark_branch() {
	local branch=$1
	local iteration=$2

	echo "📊 Testing $branch (run $iteration/$ITERATIONS)..."

	# Clear any evaluation cache
	rm -f ~/.cache/nix/eval-cache-v* 2>/dev/null || true

	# Time the evaluation
	local start=$(date +%s%N)
	NIX_SHOW_STATS=1 NIX_SHOW_STATS_PATH="/tmp/stats-${branch}-${iteration}.json" \
		nix eval ".#${FLAKE_ATTR}" \
		--option eval-cache false \
		>/dev/null 2>&1
	local end=$(date +%s%N)

	local elapsed=$(((end - start) / 1000000))
	echo "   Time: ${elapsed}ms"

	# Extract key metrics
	local cpu_time=$(jq -r '.cpuTime' "/tmp/stats-${branch}-${iteration}.json")
	local function_calls=$(jq -r '.nrFunctionCalls' "/tmp/stats-${branch}-${iteration}.json")
	local thunks=$(jq -r '.nrThunks' "/tmp/stats-${branch}-${iteration}.json")
	local heap=$(jq -r '.gc.heapSize' "/tmp/stats-${branch}-${iteration}.json")

	echo "   CPU: ${cpu_time}s, Functions: $function_calls, Thunks: $thunks, Heap: $((heap / 1024 / 1024))MB"
	echo ""

	echo "$elapsed" >>"/tmp/times-${branch}.txt"
}

# Benchmark Base Branch
echo "🌿 Switching to $BASE_BRANCH..."
git checkout "$BASE_BRANCH" >/dev/null 2>&1
rm -f "/tmp/times-${BASE_BRANCH}.txt"

for i in $(seq 1 $ITERATIONS); do
	benchmark_branch "$BASE_BRANCH" "$i"
done

# Benchmark Feature Branch
echo "🌿 Switching to $FEATURE_BRANCH..."
git checkout "$FEATURE_BRANCH" >/dev/null 2>&1
rm -f "/tmp/times-${FEATURE_BRANCH}.txt"

for i in $(seq 1 $ITERATIONS); do
	benchmark_branch "$FEATURE_BRANCH" "$i"
done

# Return to original branch
echo "🌿 Returning to $CURRENT_BRANCH..."
git checkout "$CURRENT_BRANCH" >/dev/null 2>&1

# Calculate statistics
echo "📈 Results Summary"
echo "===================="
echo ""

calc_stats() {
	local file=$1
	local avg=$(awk '{ sum += $1; count++ } END { print sum/count }' "$file")
	local min=$(sort -n "$file" | head -1)
	local max=$(sort -n "$file" | tail -1)
	echo "$avg $min $max"
}

read avg_base min_base max_base <<<$(calc_stats "/tmp/times-${BASE_BRANCH}.txt")
read avg_feature min_feature max_feature <<<$(calc_stats "/tmp/times-${FEATURE_BRANCH}.txt")

echo "$BASE_BRANCH (baseline):"
echo "  Average: ${avg_base}ms"
echo "  Min: ${min_base}ms"
echo "  Max: ${max_base}ms"
echo ""

echo "$FEATURE_BRANCH (feature):"
echo "  Average: ${avg_feature}ms"
echo "  Min: ${min_feature}ms"
echo "  Max: ${max_feature}ms"
echo ""

# Calculate improvement
improvement=$(awk "BEGIN { printf \"%.2f\", (($avg_base - $avg_feature) / $avg_base * 100) }")

if (($(echo "$improvement > 0" | bc -l))); then
	echo "✅ $FEATURE_BRANCH is ${improvement}% FASTER than $BASE_BRANCH"
elif (($(echo "$improvement < 0" | bc -l))); then
	improvement=$(echo "$improvement * -1" | bc)
	echo "⚠️  $FEATURE_BRANCH is ${improvement}% SLOWER than $BASE_BRANCH"
else
	echo "➖ No significant difference"
fi

echo ""
echo "📁 Detailed stats saved in /tmp/stats-*.json"

# Cleanup
rm -f "/tmp/times-${BASE_BRANCH}.txt" "/tmp/times-${FEATURE_BRANCH}.txt"
