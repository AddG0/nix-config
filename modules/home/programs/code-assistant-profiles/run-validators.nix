# Rebuilds the files each enabled tool reads from a home config as a fake $HOME, and runs that tool's own validator over it.
{
  pkgs,
  lib,
}:
# name: the check's subject in messages. homes: user name to evaluated home-manager config.
{
  name,
  homes,
}: let
  validatorTimeoutSeconds = 120;

  rel = lib.removePrefix "/";
  under = dirs: target: lib.any (dir: rel target == dir || lib.hasPrefix "${dir}/" (rel target)) dirs;

  validatorsOf = hm: lib.attrValues hm.programs.code-assistant-profiles.validators;

  checkedPackage = user: validator:
    lib.throwIf (validator.package == null) "${name}: ${validator.option}.package is null for user ${user}, so that tool's validator cannot run" validator.package;

  forUser = user: hm: let
    xdgConfig =
      lib.throwIfNot (lib.hasPrefix "${hm.home.homeDirectory}/" hm.xdg.configHome)
      "${name}: xdg.configHome ${hm.xdg.configHome} is outside ${hm.home.homeDirectory} for user ${user}, so the fake $HOME cannot hold it"
      (rel (lib.removePrefix hm.home.homeDirectory hm.xdg.configHome));

    enabled = lib.filter (validator: validator.enable) (validatorsOf hm);
    toolDirs = lib.concatMap (validator: validator.configDirs ++ validator.extraDirs) enabled;
    mergedFiles = lib.concatMap (validator: validator.mergedFiles) enabled;
    files = lib.filter (file: (file.enable || lib.elem (rel file.target) mergedFiles) && under toolDirs file.target) (lib.attrValues hm.home.file);

    # A layout change that selects nothing would otherwise pass on an empty $HOME.
    emptyTools = lib.filter (validator: !(lib.any (file: under validator.configDirs file.target) files)) enabled;

    fakeHome = pkgs.runCommandLocal "assistant-config-home-${name}-${user}" {} (''
        mkdir -p "$out"
      ''
      + lib.concatMapStrings (file: let
        target = lib.escapeShellArg (rel file.target);
      in ''
        mkdir -p "$out/$(dirname ${target})"
        cp -rsT --no-preserve=mode ${file.source} "$out/"${target}
      '')
      files);
  in
    lib.throwIf (emptyTools != []) "${name}: ${lib.concatMapStringsSep ", " (validator: validator.option) emptyTools} enabled for user ${user}, but no home.file entry lands under ${lib.concatMapStringsSep ", " (validator: lib.concatStringsSep " " validator.configDirs) emptyTools}"
    (''
        subject=${lib.escapeShellArg (name + lib.optionalString (lib.length (lib.attrNames homes) > 1) " (${user})")}
        home="$TMPDIR/home-"${lib.escapeShellArg user}
        cp -rL --no-preserve=mode ${fakeHome} "$home"
      ''
      # Each tool runs as its own job with a private $HOME, $TMPDIR and tallies, so tools that write state never share a file.
      + lib.concatImapStrings (i: validator: ''
        job="$TMPDIR/jobs/"${lib.escapeShellArg "${user}-${toString i}"}
        mkdir -p "$job/tmp" "$job/cwd"
        cp -r "$home" "$job/home"
        (
          cd "$job/cwd"
          export HOME="$job/home"
          export XDG_CONFIG_HOME="$HOME/"${lib.escapeShellArg xdgConfig}
          export TMPDIR="$job/tmp"
          ran="$job/ran"
          failed=0
          : >"$ran"
          ${validator.script (checkedPackage user validator)}
          echo "$failed" >"$job/failed"
        ) 2>"$job/stderr" &
        jobs+=("$job" "$!")
      '')
      enabled);

  setups = lib.unique (lib.concatMap (hm: map (validator: validator.setup) (validatorsOf hm)) (lib.attrValues homes));
in
  pkgs.runCommandLocal "assistant-config-check-${name}" {env.NO_COLOR = "1";} ''
    failed=0
    limit=${toString validatorTimeoutSeconds}
    ran="$TMPDIR/ran"
    touch "$ran"
    mkdir -p "$TMPDIR/cwd"
    cd "$TMPDIR/cwd"

    plain() { sed -E 's/\x1b\[[0-9;?<>]*[a-zA-Z]//g; s/\x1b[78]//g'; }

    report() {
      failed=$((failed + 1))
      printf '%s: %s: %s: `%s` rejected it:\n%s\n\n' "$subject" "$1" "$2" "$3" "$(plain <<<"$4")" >&2
    }

    # validate <tool> <file> <command...>: reports the command's output when it exits non-zero.
    validate() {
      local tool=$1 file=$2 out status=0
      shift 2
      out=$(timeout "$limit" "$@" 2>&1 </dev/null) || status=$?
      local shown="''${1##*/} ''${*:2}"
      echo "$subject: $tool: $file: ''${1##*/} ''${*:2:2}" >>"$ran"
      if [[ $status -eq 124 ]]; then
        report "$tool" "$file" "$shown" "timed out after $limit s"$'\n'"$out"
      elif [[ $status -ne 0 ]]; then
        report "$tool" "$file" "$shown" "$out"
      fi
    }

    jobs=()
    ${lib.concatStrings setups}
    ${lib.concatStrings (lib.mapAttrsToList forUser homes)}

    # Collected in launch order, so the report reads the same whatever order the jobs finish in.
    for ((i = 0; i < ''${#jobs[@]}; i += 2)); do
      job=''${jobs[i]}
      status=0
      wait "''${jobs[i + 1]}" || status=$?
      cat "$job/stderr" >&2
      cat "$job/ran" >>"$ran"
      if [[ $status -ne 0 || ! -f $job/failed ]]; then
        failed=$((failed + 1))
        echo "${name}: validator job ''${job##*/} exited $status before reporting its result" >&2
      else
        failed=$((failed + $(cat "$job/failed")))
      fi
    done

    if [[ $failed -ne 0 ]]; then
      echo "${name}: $failed validator run(s) rejected the generated assistant config; see above" >&2
      exit 1
    fi
    if [[ ! -s $ran ]]; then
      echo "${name}: no validator ran over the generated assistant config, so nothing was checked" >&2
      exit 1
    fi
    cp "$ran" "$out"
  ''
