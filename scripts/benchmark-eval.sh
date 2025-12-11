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
ITERATIONS="${4:-5}"
WARMUP_RUNS=1

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

# Report system conditions
echo "💻 System Conditions:"
if [ "$OS_TYPE" = "darwin" ]; then
	# macOS
	cpu_freq=$(sysctl -n hw.cpufrequency 2>/dev/null || echo "unknown")
	if [ "$cpu_freq" != "unknown" ]; then
		cpu_freq_ghz=$(awk "BEGIN { printf \"%.2f\", $cpu_freq / 1000000000 }")
		echo "  CPU Frequency: ${cpu_freq_ghz} GHz"
	else
		echo "  CPU Frequency: unavailable"
	fi
else
	# Linux
	cpu_freq=$(grep "cpu MHz" /proc/cpuinfo | head -1 | awk '{print $4}')
	if [ -n "$cpu_freq" ]; then
		cpu_freq_ghz=$(awk "BEGIN { printf \"%.2f\", $cpu_freq / 1000 }")
		echo "  CPU Frequency: ${cpu_freq_ghz} GHz"
	else
		echo "  CPU Frequency: unavailable"
	fi
fi

load_avg=$(uptime | awk -F'load average:' '{print $2}' | xargs)
echo "  Load Average: $load_avg"
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

# Initialize result files
rm -f "/tmp/times-${BASE_BRANCH}.txt" "/tmp/times-${FEATURE_BRANCH}.txt"

# Warmup runs (not measured)
if [ $WARMUP_RUNS -gt 0 ]; then
	echo "🔥 Running $WARMUP_RUNS warmup iteration(s)..."
	for i in $(seq 1 $WARMUP_RUNS); do
		git checkout "$BASE_BRANCH" >/dev/null 2>&1
		echo "   Warmup $i/$WARMUP_RUNS on $BASE_BRANCH..."
		rm -f ~/.cache/nix/eval-cache-v* 2>/dev/null || true
		nix eval ".#${FLAKE_ATTR}" --option eval-cache false >/dev/null 2>&1

		git checkout "$FEATURE_BRANCH" >/dev/null 2>&1
		echo "   Warmup $i/$WARMUP_RUNS on $FEATURE_BRANCH..."
		rm -f ~/.cache/nix/eval-cache-v* 2>/dev/null || true
		nix eval ".#${FLAKE_ATTR}" --option eval-cache false >/dev/null 2>&1
	done
	echo ""
fi

# Interleaved benchmark runs (ABABAB pattern)
echo "🔬 Running interleaved benchmarks..."
for i in $(seq 1 $ITERATIONS); do
	# Test base branch
	echo "🌿 Switching to $BASE_BRANCH..."
	git checkout "$BASE_BRANCH" >/dev/null 2>&1
	benchmark_branch "$BASE_BRANCH" "$i"

	# Test feature branch
	echo "🌿 Switching to $FEATURE_BRANCH..."
	git checkout "$FEATURE_BRANCH" >/dev/null 2>&1
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

	# Calculate median
	local count=$(wc -l <"$file")
	local median
	if [ $((count % 2)) -eq 0 ]; then
		# Even number of values - average of middle two
		local mid1=$((count / 2))
		local mid2=$((mid1 + 1))
		median=$(sort -n "$file" | awk "NR==$mid1 || NR==$mid2 { sum += \$1; count++ } END { print sum/count }")
	else
		# Odd number of values - middle value
		local mid=$(((count + 1) / 2))
		median=$(sort -n "$file" | awk "NR==$mid { print \$1 }")
	fi

	# Calculate standard deviation
	local stddev=$(awk -v avg="$avg" '{ sum += ($1 - avg)^2; count++ } END { print sqrt(sum/count) }' "$file")

	echo "$avg $min $max $median $stddev"
}

detect_outliers() {
	local file=$1
	local branch=$2
	local avg=$3
	local stddev=$4
	local threshold=2

	local outliers=$(awk -v avg="$avg" -v stddev="$stddev" -v threshold="$threshold" '
		{
			deviation = ($1 - avg) / stddev
			if (deviation < 0) deviation = -deviation
			if (deviation > threshold) {
				print "    Run " NR ": " $1 "ms (±" sprintf("%.2f", deviation) "σ)"
			}
		}
	' "$file")

	if [ -n "$outliers" ]; then
		echo "⚠️  Outliers detected in $branch (>2σ from mean):"
		echo "$outliers"
		return 0
	else
		return 1
	fi
}

read avg_base min_base max_base median_base stddev_base <<<$(calc_stats "/tmp/times-${BASE_BRANCH}.txt")
read avg_feature min_feature max_feature median_feature stddev_feature <<<$(calc_stats "/tmp/times-${FEATURE_BRANCH}.txt")

echo "$BASE_BRANCH (baseline):"
echo "  Average: ${avg_base}ms"
echo "  Median:  ${median_base}ms"
echo "  Std Dev: ${stddev_base}ms"
echo "  Min:     ${min_base}ms"
echo "  Max:     ${max_base}ms"
echo ""

echo "$FEATURE_BRANCH (feature):"
echo "  Average: ${avg_feature}ms"
echo "  Median:  ${median_feature}ms"
echo "  Std Dev: ${stddev_feature}ms"
echo "  Min:     ${min_feature}ms"
echo "  Max:     ${max_feature}ms"
echo ""

# Detect outliers
detect_outliers "/tmp/times-${BASE_BRANCH}.txt" "$BASE_BRANCH" "$avg_base" "$stddev_base" && echo ""
detect_outliers "/tmp/times-${FEATURE_BRANCH}.txt" "$FEATURE_BRANCH" "$avg_feature" "$stddev_feature" && echo ""

# Calculate improvement (using both average and median)
improvement_avg=$(awk "BEGIN { printf \"%.2f\", (($avg_base - $avg_feature) / $avg_base * 100) }")
improvement_median=$(awk "BEGIN { printf \"%.2f\", (($median_base - $median_feature) / $median_base * 100) }")

echo "📊 Performance Comparison:"
if (($(echo "$improvement_avg > 0" | bc -l))); then
	echo "✅ $FEATURE_BRANCH is ${improvement_avg}% FASTER (avg) than $BASE_BRANCH"
elif (($(echo "$improvement_avg < 0" | bc -l))); then
	local abs_improvement=$(echo "$improvement_avg * -1" | bc)
	echo "⚠️  $FEATURE_BRANCH is ${abs_improvement}% SLOWER (avg) than $BASE_BRANCH"
else
	echo "➖ No significant difference (avg)"
fi

if (($(echo "$improvement_median > 0" | bc -l))); then
	echo "✅ $FEATURE_BRANCH is ${improvement_median}% FASTER (median) than $BASE_BRANCH"
elif (($(echo "$improvement_median < 0" | bc -l))); then
	local abs_improvement=$(echo "$improvement_median * -1" | bc)
	echo "⚠️  $FEATURE_BRANCH is ${abs_improvement}% SLOWER (median) than $BASE_BRANCH"
else
	echo "➖ No significant difference (median)"
fi

echo ""
echo "📁 Detailed stats saved in /tmp/stats-*.json"

# Cleanup
rm -f "/tmp/times-${BASE_BRANCH}.txt" "/tmp/times-${FEATURE_BRANCH}.txt"
