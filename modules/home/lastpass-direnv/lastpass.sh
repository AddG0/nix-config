#!/usr/bin/env bash

from_lpass() {
    local LP_VARIABLES=()
    local LP_FILES=()
    local OVERWRITE_ENVVARS=1
    local VERBOSE=0
    while [[ $# -gt 0 ]]; do
        case $1 in
        --no-overwrite)
            OVERWRITE_ENVVARS=0
            shift
            ;;
        --verbose)
            VERBOSE=1
            shift
            ;;
        --*)
            log_error "from_lpass: Unknown option: $1"
            return 1
            ;;
        *=*)
            LP_VARIABLES+=("$1")
            shift
            ;;
        *)
            LP_FILES+=("$1")
            watch_file "$1"
            shift
            ;;
        esac
    done

    if [[ -t 0 ]] && [[ ${#LP_VARIABLES[@]} == 0 ]] && [[ ${#LP_FILES[@]} == 0 ]]; then
        log_error "from_lpass: No input nor arguments given"
        return 1
    fi

    local LP_INPUT
    LP_INPUT="$(
        # Concatenate variable-args, file-args and stdin.
        printf '%s\n' "${LP_VARIABLES[@]}"
        [[ "${#LP_FILES[@]}" == 0 ]] || cat "${LP_FILES[@]}"
        [[ -t 0 ]] || cat
    )"

    if [[ "$OVERWRITE_ENVVARS" = "0" ]]; then
        # Remove variables from LP_INPUT that are already set in the environment.
        LP_INPUT="$(
            echo "$LP_INPUT" | while read -r line; do
                if [[ "$line" =~ ^([^=]+)= ]]; then
                    VARIABLE_NAME="${BASH_REMATCH[1]}"
                    if [[ -z "${!VARIABLE_NAME}" ]]; then
                        echo "$line"
                    fi
                fi
            done
        )"
    fi

    if [[ -z "$LP_INPUT" ]]; then
        # There are no environment variables to load from lpass, no need to run lpass.
        [[ "$VERBOSE" == "0" ]] || log_status "from_lpass: No variables to load from LastPass"
        return 0
    fi

    [[ "$VERBOSE" == "0" ]] || log_status "from_lpass: Loading variables from LastPass"

    if ! has lpass; then
        log_error "LastPass CLI 'lpass' not found"
        return 1
    fi

    # Check if logged in
    if ! lpass status >/dev/null 2>&1; then
        log_error "Not logged in to LastPass. Run 'lpass login <username>' first."
        return 1
    fi

    # Process each line and get the secret value
    echo "$LP_INPUT" | while read -r line; do
        if [[ "$line" =~ ^([^=]+)=(.+)$ ]]; then
            local var_name="${BASH_REMATCH[1]}"
            local secret_name="${BASH_REMATCH[2]}"

            # Get password from LastPass
            local secret_value
            if secret_value="$(lpass show --password "$secret_name" 2>/dev/null)" && [[ -n "$secret_value" ]]; then
                # Export the variable using direnv's export function
                export "$var_name"="$secret_value"
                [[ "$VERBOSE" == "0" ]] || log_status "from_lpass: Loaded $var_name from $secret_name"
            else
                log_error "from_lpass: Failed to get secret '$secret_name' for variable '$var_name'"
                return 1
            fi
        fi
    done
}