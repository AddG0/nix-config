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

  # Gate the instance writes on Prism not running. Prism holds instance.cfg in
  # memory and rewrites the whole file on any settings change, so writing under a
  # live launcher is silently reverted. Sets $prismSkip=1 to suppress the writes.
  mkRunningGuard = {mode}: let
    procps = "${pkgs.procps}/bin";
    # The game runs as a java child, so match the launcher's own binary exactly.
    running = "${procps}/pgrep -x prismlauncher >/dev/null 2>&1";
    gameRunning = "${procps}/pgrep -f org.prismlauncher.EntryPoint >/dev/null 2>&1";
    # SIGTERM: Prism flushes its settings on a clean quit, so a kill -9 here would
    # race the very writes we are about to make.
    closePrism = ''
      run ${procps}/pkill -x prismlauncher || true
      for _ in $(seq 1 100); do
        ${running} || break
        sleep 0.1
      done
      if ${running}; then
        warnEcho "Prism Launcher did not exit; skipping instance updates"
        prismSkip=1
      else
        noteEcho "Closed Prism Launcher to update instances"
      fi
    '';
  in
    if mode == "ignore"
    then ""
    else ''
      prismSkip=""
      if ${running}; then
        ${
        if mode == "skip"
        then ''
          warnEcho "Prism Launcher is running; skipping instance updates until next activation"
          prismSkip=1
        ''
        else if mode == "close"
        then ''
          if ${gameRunning}; then
            warnEcho "Prism Launcher has a game running; skipping instance updates"
            prismSkip=1
          else
            ${closePrism}
          fi
        ''
        else closePrism
      }
      fi
    '';

  # Setup individual instance
  mkInstanceSetup = {
    name,
    prismDir,
    mmcPackJson,
    instanceCfg,
    worldSetupScript ? "",
    serversSetupScript ? "",
  }: ''
    # Instance: ${name}
    run mkdir -p "${prismDir}/instances/${name}/.minecraft"

    # Always update mmc-pack.json (loader versions from pack.toml)
    run cat > "${prismDir}/instances/${name}/mmc-pack.json" << 'MMCPACK'
    ${mmcPackJson}
    MMCPACK

    # Always overwrite instance.cfg with managed config
    run cat > "${prismDir}/instances/${name}/instance.cfg" << 'INSTCFG'
    ${instanceCfg}
    INSTCFG

    ${worldSetupScript}
    ${serversSetupScript}
  '';

  # Sync declared servers into an instance's servers.dat. servers.dat is writable
  # game state (Minecraft rewrites it), so it's created here rather than symlinked.
  # The state file tracks module-managed addresses; guard on it so an emptied list
  # still runs once to clean up, but untouched instances are skipped.
  mkServersSetupScript = {
    prismDir,
    instanceName,
    serversJsonFile,
  }: let
    minecraftDir = "${prismDir}/instances/${instanceName}/.minecraft";
    stateFile = "${prismDir}/instances/${instanceName}/.nix-managed-servers.json";
  in ''
    if [ "$(cat ${serversJsonFile})" != "[]" ] || [ -e "${stateFile}" ]; then
      run mkdir -p ${minecraftDir}
      run ${pkgs.python3}/bin/python3 ${./servers-merge.py} ${serversJsonFile} "${minecraftDir}/servers.dat" "${stateFile}"
    fi
  '';
}
