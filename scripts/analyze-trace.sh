#!/usr/bin/env bash
# analyze-trace.sh - Profile and analyze Nix evaluation performance
# Usage: ./analyze-trace.sh [hostname] [use-existing]
# Requirements: ripgrep (rg), GNU sort with parallel support

set -e

# Get hostname (defaults to current hostname)
HOST="${1:-$(hostname)}"

# Detect OS and build flake path
if [ "$(uname -s)" = "Darwin" ]; then
	FLAKE_PATH=".#darwinConfigurations.${HOST}.system"
	OS_TYPE="darwin"
else
	FLAKE_PATH=".#nixosConfigurations.${HOST}.config.system.build.toplevel"
	OS_TYPE="nixos"
fi

echo "🔬 Nix Evaluation Profiler"
echo "=========================="
echo "Host: ${HOST} (${OS_TYPE})"
echo "Flake: ${FLAKE_PATH}"
echo ""

USE_EXISTING="${2:-y}"

if [ -f trace.log ]; then
	echo "Found existing trace.log ($(ls -lh trace.log | awk '{print $5}'))"
	if [ "$USE_EXISTING" != "y" ] && [ "$USE_EXISTING" != "Y" ]; then
		echo "Regenerating trace.log..."
		rm trace.log
	else
		echo "Using existing trace.log"
	fi
fi

if [ ! -f trace.log ]; then
	echo "Generating trace log (this will take 30-60 seconds and create ~5GB file)..."
	echo ""
	nix eval "${FLAKE_PATH}" --trace-function-calls 2>trace.log >/dev/null
	echo "✓ Trace generated: $(ls -lh trace.log | awk '{print $5}')"
	echo ""
fi

echo "Analyzing function calls..."
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Top 20 Most Called Functions (by file)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
rg --no-filename "function-trace entered" trace.log |
	awk '{print $3}' |
	sed 's/:[0-9]*:[0-9]*$//' |
	sort --parallel=4 | uniq -c | sort --parallel=4 -rn |
	head -20 |
	awk '{printf "%12s calls  %s\n", $1, $2}'

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Your Config Files (from nix-config)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Dynamically find the nix-config store path
# Look for the first store path that evaluates flake.nix (that's your config)
CONFIG_STORE=$(rg "function-trace entered.*-source/flake\.nix" trace.log |
	head -1 |
	rg -o '/nix/store/[a-z0-9]+-source')

if [ -n "$CONFIG_STORE" ]; then
	echo "Detected config at: $CONFIG_STORE"
	echo ""
	rg --no-filename "function-trace entered" trace.log |
		rg "$CONFIG_STORE" |
		awk '{print $3}' |
		sed 's/:[0-9]*:[0-9]*$//' |
		sed "s|$CONFIG_STORE/||" |
		sort --parallel=4 | uniq -c | sort --parallel=4 -rn |
		head -20 |
		awk '{printf "%6s calls  %s\n", $1, $2}'
else
	echo "⚠️  Could not auto-detect nix-config store path"
	echo "Looking for any local config files..."
	rg --no-filename "function-trace entered" trace.log |
		rg "/(lib|modules|home|hosts|overlays)/" |
		awk '{print $3}' |
		sed 's/:[0-9]*:[0-9]*$//' |
		sort --parallel=4 | uniq -c | sort --parallel=4 -rn |
		head -20 |
		awk '{printf "%6s calls  %s\n", $1, $2}'
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Nixpkgs Copies Detected"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
rg --no-filename "function-trace entered" trace.log |
	rg "/nix/store" |
	awk '{print $3}' |
	rg -o '/nix/store/[a-z0-9]+-source' |
	sort --parallel=4 -u |
	while read path; do
		count=$(rg -c "$path" trace.log || echo 0)
		printf "%12s calls  %s\n" "$count" "$path"
	done | sort --parallel=4 -rn | head -10

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Statistics"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
total_lines=$(wc -l <trace.log)
function_calls=$(rg -c "function-trace entered" trace.log)
file_size=$(ls -lh trace.log | awk '{print $5}')

echo "Total trace lines:    $total_lines"
echo "Function calls:       $function_calls"
echo "Trace file size:      $file_size"

echo ""
echo "💡 Tip: To see specific file details:"
echo "   grep 'mysql.nix' trace.log | wc -l"
echo ""
echo "💡 To cleanup:"
echo "   rm trace.log  # Frees ~5GB"
