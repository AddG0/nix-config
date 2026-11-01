# Moves @root under old_roots/<its mtime>, drops kept roots past 30 days, and creates an empty @root.
{
  mountDir,
  device,
}: ''
  mkdir -p ${mountDir}
  mount ${device} ${mountDir}
  trap 'umount ${mountDir}' EXIT
  if [[ -e ${mountDir}/@root ]]; then
    mkdir -p ${mountDir}/old_roots
    timestamp=$(date --date="@$(stat -c %Y ${mountDir}/@root)" "+%Y-%m-%d_%H:%M:%S")
    mv ${mountDir}/@root "${mountDir}/old_roots/$timestamp"
    # The 30 days count from archiving, not from the boot that root served.
    touch "${mountDir}/old_roots/$timestamp"
  fi

  for i in $(find ${mountDir}/old_roots/ -mindepth 1 -maxdepth 1 -mtime +30); do
    btrfs subvolume delete --recursive "$i"
  done

  btrfs subvolume create ${mountDir}/@root
''
