#!/usr/bin/env bash
# Report the on-disk closure size of a flake output, optionally with a
# per-path breakdown of the largest contributors.
#
# Usage:
#   scripts/closure.sh                                       # current host's system
#   scripts/closure.sh dragon                                # another host
#   scripts/closure.sh dragon --top 25                       # + top-25 breakdown
#   scripts/closure.sh .#homeConfigurations.cloud-shell.activationPackage --impure --top 25
#   scripts/closure.sh --json                                # machine-readable
#
# A <target> that contains '#' is treated as a full installable and used as-is.
# Anything else is wrapped as ".#{nixos,darwin}Configurations.<target>.config.system.build.toplevel".

set -euo pipefail

usage() {
	sed -n '2,/^$/p' "$0" | sed 's/^# \?//'
}

# Defaults
target=""
target_set=0
top=0
impure=0
json=0

while [ $# -gt 0 ]; do
	case "$1" in
	--impure)
		impure=1
		shift
		;;
	--json)
		json=1
		shift
		;;
	--top)
		top="${2:-}"
		shift 2
		;;
	--top=*)
		top="${1#--top=}"
		shift
		;;
	-h | --help)
		usage
		exit 0
		;;
	--)
		shift
		[ $# -gt 0 ] && {
			target="$1"
			target_set=1
			shift
		}
		;;
	-*)
		echo "closure.sh: unknown flag: $1" >&2
		exit 2
		;;
	*)
		if [ "$target_set" -eq 0 ]; then
			target="$1"
			target_set=1
			shift
		else
			echo "closure.sh: unexpected extra positional: $1" >&2
			exit 2
		fi
		;;
	esac
done

[[ $top =~ ^[0-9]+$ ]] || {
	echo "closure.sh: --top must be a non-negative integer (got '$top')" >&2
	exit 1
}

# Pick the host attribute set for this OS.
attr_root="nixosConfigurations"
[ "$(uname -s)" = "Darwin" ] && attr_root="darwinConfigurations"

case "$target" in
*"#"*) ref="$target" ;;                                              # full installable, use as-is
"") ref=".#${attr_root}.$(hostname).config.system.build.toplevel" ;; # current host
*) ref=".#${attr_root}.${target}.config.system.build.toplevel" ;;    # named host
esac

echo "Building ${ref} (no-op if already realised)..." >&2

build_flags=(--no-link --print-out-paths --quiet)
[ "$impure" -eq 1 ] && build_flags+=(--impure)
out=$(nix build "${build_flags[@]}" "$ref")

# Self + closure size in one call. --json-format 1 keeps the legacy
# keyed-by-path shape and silences the deprecation warning.
info=$(nix path-info --size --closure-size --json --json-format 1 "$out")
nar_size=$(jq -r '.[].narSize' <<<"$info")
closure_size=$(jq -r '.[].closureSize' <<<"$info")

if [ "$top" -gt 0 ]; then
	breakdown_json=$(nix path-info -r --size --json --json-format 1 "$out" |
		jq -c --argjson n "$top" \
			'[to_entries[] | {narSize: .value.narSize, path: .key}]
                 | sort_by(-.narSize) | .[:$n]')
	top_sum=$(jq '[.[].narSize] | add // 0' <<<"$breakdown_json")
else
	breakdown_json='[]'
	top_sum=0
fi

if [ "$json" -eq 1 ]; then
	# jq auto-detects: colored pretty-print on a TTY, plain multi-line when
	# piped. Real JSON consumers (jq, python, node …) handle either fine.
	jq -n \
		--arg ref "$ref" \
		--arg outPath "$out" \
		--argjson nar "$nar_size" \
		--argjson cls "$closure_size" \
		--argjson tops "$breakdown_json" \
		--argjson tsum "$top_sum" \
		'{ref: $ref, outPath: $outPath, narSize: $nar, closureSize: $cls,
          top: $tops, topSumNarSize: $tsum}'
else
	printf '%s\tself %s\tclosure %s\n' \
		"$out" \
		"$(numfmt --to=iec <<<"$nar_size")" \
		"$(numfmt --to=iec <<<"$closure_size")"
	if [ "$top" -gt 0 ]; then
		echo
		echo "Largest paths in the closure (own size):"
		jq -r '.[] | "\(.narSize)\t\(.path)"' <<<"$breakdown_json" |
			numfmt --to=iec --field=1 --padding=9
		if [ "$closure_size" -gt 0 ]; then
			pct=$((top_sum * 100 / closure_size))
			printf '\nTop %s paths cover %s%% of the closure (%s of %s).\n' \
				"$top" "$pct" \
				"$(numfmt --to=iec <<<"$top_sum")" \
				"$(numfmt --to=iec <<<"$closure_size")"
		fi
	fi
fi
