# `decky-follow-user <boot-env> <user-env>`: pam_exec at a console login points Decky's plugins at that user.
{
  pkgs,
  runtimeInputs,
}:
pkgs.writeShellApplication {
  name = "decky-follow-user";
  inherit runtimeInputs;
  text = ''
    boot_env=$1
    user_env=$2
    exec > >(systemd-cat -t decky-user) 2>&1
    uid=$(id -u "$PAM_USER")
    # Greeters and other system users never run Steam.
    if ((uid < 1000)); then exit 0; fi
    home=$(getent passwd "$PAM_USER" | cut -d: -f6)
    if [[ -z $home ]]; then
      echo "no home directory for $PAM_USER in passwd; Decky keeps its current user" >&2
      exit 1
    fi
    data="$home/.local/share/decky"
    # Root-created, the plugins running as the user could not write it.
    if [[ ! -d $data ]]; then
      echo "$data is missing (tmpfiles creates it for hostSpec users only); Decky keeps its current user" >&2
      exit 1
    fi
    env="UNPRIVILEGED_USER=$PAM_USER
    UNPRIVILEGED_PATH=$data"
    if [[ -e $user_env ]]; then current=$(cat "$user_env"); else current=$(cat "$boot_env"); fi
    if [[ $current == "$env" ]]; then exit 0; fi
    mkdir -p "$(dirname "$user_env")"
    tmp=""
    trap 'rm -f "$tmp"' EXIT
    tmp=$(mktemp "$(dirname "$user_env")/.user.env.XXXXXX")
    printf '%s\n' "$env" > "$tmp"
    mv "$tmp" "$user_env"
    if ! systemctl restart --no-block decky-loader.service; then
      # Put back the env Decky still runs with, so this user's next login retries.
      printf '%s\n' "$current" > "$user_env"
      echo "could not queue a decky-loader restart for $PAM_USER; Decky keeps its current user" >&2
      exit 1
    fi
    echo "queued a decky-loader restart to run plugins as $PAM_USER with data in $data"
  '';
}
