# x3d-cache-ccd [cpu-dir]: prints the largest-L3 CPUs and the rest as CPU lists ("0-7,16-23 8-15,24-31"); exits 3 when every CPU shares one L3 size.
{
  writeShellApplication,
  coreutils,
  gawk,
}:
writeShellApplication {
  name = "x3d-cache-ccd";
  runtimeInputs = [coreutils gawk];
  text = ''
    shopt -s inherit_errexit
    ${builtins.readFile ./cpu-lists.bash}
    cpus=''${1:-/sys/devices/system/cpu}

    rows=$(
      for dir in "$cpus"/cpu[0-9]*; do
        [ -r "$dir/cache/index3/size" ] || continue
        if [ -r "$dir/online" ] && [ "$(cat "$dir/online")" = 0 ]; then continue; fi
        size=$(cat "$dir/cache/index3/size")
        if [[ ! $size =~ ^[0-9]+K$ ]]; then
          echo "x3d-cache-ccd: $dir reports an L3 size of '$size', not <n>K" >&2
          exit 1
        fi
        echo "''${dir##*/cpu} ''${size%K}"
      done | sort -n
    )
    if [ -z "$rows" ]; then
      echo "x3d-cache-ccd: no online CPU under $cpus reports an L3 cache size" >&2
      exit 1
    fi

    largest=$(cut -d' ' -f2 <<<"$rows" | sort -n | tail -1)
    cache=$(awk -v l="$largest" '$2 == l {print $1}' <<<"$rows" | compress_cpus)
    other=$(awk -v l="$largest" '$2 != l {print $1}' <<<"$rows" | compress_cpus)
    if [ -z "$other" ]; then
      echo "x3d-cache-ccd: every CPU under $cpus has the same L3 cache; there is no cache CCD" >&2
      exit 3
    fi
    echo "$cache $other"
  '';
}
