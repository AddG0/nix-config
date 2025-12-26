# Shell scripts for Prism Launcher module
{pkgs}: {
  # Cleanup orphaned instances
  mkCleanupScript = {
    prismDir,
    managedInstancesStr,
  }: ''
    # Cleanup orphaned instances managed by this module
    if [ -d "${prismDir}/instances" ]; then
      managed_instances="${managedInstancesStr}"
      for instance_dir in "${prismDir}/instances"/*/; do
        [ -d "$instance_dir" ] || continue
        instance_name="$(basename "$instance_dir")"
        # Check if instance has our PreLaunchCommand marker (managed by us)
        if [ -f "$instance_dir/instance.cfg" ] && grep -q "packwiz-installer-bootstrap" "$instance_dir/instance.cfg"; then
          is_managed=false
          for managed in $managed_instances; do
            if [ "$instance_name" = "$managed" ]; then
              is_managed=true
              break
            fi
          done
          if [ "$is_managed" = "false" ]; then
            run rm -rf "$instance_dir"
            noteEcho "Removed orphaned instance: $instance_name"
          fi
        fi
      done
    fi
  '';

  # Update instance groups
  mkUpdateGroupsScript = {
    prismDir,
    instGroupsJson,
  }: ''
    # Update instance groups
    groups_file="${prismDir}/instances/instgroups.json"
    managed_groups='${instGroupsJson}'

    if [ -f "$groups_file" ]; then
      # Merge: keep existing groups, update managed ones
      ${pkgs.jq}/bin/jq -s '
        .[0] as $existing |
        .[1] as $managed |
        {
          formatVersion: "1",
          groups: ($existing.groups // {}) * ($managed.groups // {})
        }
      ' "$groups_file" <(echo "$managed_groups") > "$groups_file.tmp"
      run mv "$groups_file.tmp" "$groups_file"
    else
      # Create new file
      run mkdir -p "$(dirname "$groups_file")"
      echo "$managed_groups" > "$groups_file"
    fi
  '';

  # Setup individual instance
  mkInstanceSetup = {
    name,
    prismDir,
    packwizDir,
    mmcPackJson,
    instanceCfg,
    mutableOverrides,
  }: ''
    # Instance: ${name}
    run mkdir -p "${prismDir}/instances/${name}/.minecraft"

    # Always update mmc-pack.json (loader versions from pack.toml)
    run cat > "${prismDir}/instances/${name}/mmc-pack.json" << 'MMCPACK'
    ${mmcPackJson}
    MMCPACK

    # Always update instance.cfg (for config changes like javaArgs, icon)
    run cat > "${prismDir}/instances/${name}/instance.cfg" << 'INSTCFG'
    ${instanceCfg}
    INSTCFG

    ${
      if !mutableOverrides
      then ''
        # Sync overrides (mutableOverrides = false)
        # Note: Use yosbr mod for config merging (configs go in config/yosbr/)
        if [ -d "${packwizDir}/${name}/overrides" ]; then
          ${pkgs.rsync}/bin/rsync -a \
            --chmod=Du=rwx,Dgo=rx,Fu=rw,Fgo=r \
            "${packwizDir}/${name}/overrides/" \
            "${prismDir}/instances/${name}/.minecraft/"
        fi
      ''
      else ""
    }
  '';
}
