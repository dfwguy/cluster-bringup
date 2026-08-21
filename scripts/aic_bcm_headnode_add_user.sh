#!/usr/bin/env bash
# Provision one ordinary TX16K user through BCM, then install one SSH public key.

set -uo pipefail
PATH=/cm/local/apps/cmd/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH

readonly EXIT_OK=0
readonly EXIT_OPERATIONAL=1
readonly EXIT_INVALID=2
readonly BCM_PROFILE=breakfix
readonly EXPECTED_HOME_ROOT=/home
readonly LOCK_FILE=/run/lock/tx16k-bcm-add-user.lock
readonly -a APPROVED_GROUPS=(cmods nvis-eth nvis-ib)

BCM_COMMITTED=0
KEY_TEMP=""

usage() {
    cat <<'EOF'
Usage: sudo /home/nvis/utils/add_user.sh

Interactively create one TX16K BCM user and install one validated OpenSSH
public key. Accounts in the nvis primary group also require a sudo password;
the standard nvis password is assigned automatically and password-based SSH
remains disabled. Cancellation at the final confirmation makes no changes.
EOF
}

cleanup() {
    if [[ -n "$KEY_TEMP" && -e "$KEY_TEMP" ]]; then
        rm -f -- "$KEY_TEMP"
    fi
}
trap cleanup EXIT
trap 'cleanup; exit 1' HUP INT TERM

invalid() {
    printf 'ERROR: %s\n' "$*" >&2
    return "$EXIT_INVALID"
}

operational_failure() {
    printf 'ERROR: %s\n' "$*" >&2
    if (( BCM_COMMITTED )); then
        printf 'PARTIAL STATE: the BCM account was committed and has been retained. Home/key installation did not complete; no rollback was attempted.\n' >&2
    fi
    return "$EXIT_OPERATIONAL"
}

resolve_command() {
    local name=$1 resolved
    resolved=$(command -v -- "$name" 2>/dev/null) || return 1
    [[ -x "$resolved" ]] || return 1
    printf '%s\n' "$resolved"
}

preflight() {
    [[ $EUID -eq 0 ]] || { invalid "this script must be run as root (use sudo)"; return $?; }

    CMSH=$(resolve_command cmsh) || { operational_failure "required command not found: cmsh"; return $?; }
    GETENT=$(resolve_command getent) || { operational_failure "required command not found: getent"; return $?; }
    MKHOMEDIR_HELPER=$(resolve_command mkhomedir_helper) || { operational_failure "required command not found: mkhomedir_helper"; return $?; }
    SSH_KEYGEN=$(resolve_command ssh-keygen) || { operational_failure "required command not found: ssh-keygen"; return $?; }
    FLOCK=$(resolve_command flock) || { operational_failure "required command not found: flock"; return $?; }
    INSTALL=$(resolve_command install) || { operational_failure "required command not found: install"; return $?; }
    STAT=$(resolve_command stat) || { operational_failure "required command not found: stat"; return $?; }
    CHMOD=$(resolve_command chmod) || { operational_failure "required command not found: chmod"; return $?; }
    CHOWN=$(resolve_command chown) || { operational_failure "required command not found: chown"; return $?; }
    MKTEMP=$(resolve_command mktemp) || { operational_failure "required command not found: mktemp"; return $?; }

    [[ -d "$EXPECTED_HOME_ROOT" && ! -L "$EXPECTED_HOME_ROOT" && -w "$EXPECTED_HOME_ROOT" ]] || {
        operational_failure "$EXPECTED_HOME_ROOT must be a writable, non-symlinked directory"
        return $?
    }
    [[ -d /etc/skel && ! -L /etc/skel && -r /etc/skel ]] || {
        operational_failure "/etc/skel must be a readable, non-symlinked directory"
        return $?
    }

    exec 9>"$LOCK_FILE" || { operational_failure "cannot open process lock: $LOCK_FILE"; return $?; }
    "$FLOCK" -n 9 || { operational_failure "another add_user.sh process is already running"; return $?; }
}

select_group() {
    local selection
    printf 'Select the primary group:\n'
    local i
    for i in "${!APPROVED_GROUPS[@]}"; do
        printf '  %d) %s\n' "$((i + 1))" "${APPROVED_GROUPS[$i]}"
    done
    IFS= read -r -p 'Group number: ' selection || { invalid "could not read group selection"; return $?; }
    [[ "$selection" =~ ^[1-4]$ ]] || { invalid "group selection must be a number from 1 through 4"; return $?; }
    SELECTED_GROUP=${APPROVED_GROUPS[$((selection - 1))]}
}

validate_username() {
    local value=$1
    [[ "$value" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || {
        invalid "username must match ^[a-z_][a-z0-9_-]{0,31}$"
        return $?
    }
    case "$value" in
        root|admin|cmsupport|executor)
            invalid "reserved username is not allowed: $value"
            return $?
            ;;
    esac
}

resolve_group_gid() {
    local group=$1 bcm_output nss_output nss_name nss_gid

    bcm_output=$("$CMSH" -c "group; get $group id" 2>&1) || {
        operational_failure "BCM could not resolve group $group"
        return $?
    }
    BCM_GID=$(printf '%s\n' "$bcm_output" | awk 'NF == 1 && $1 ~ /^[0-9]+$/ { print $1; exit }')
    if [[ -z "$BCM_GID" ]]; then
        BCM_GID=$(printf '%s\n' "$bcm_output" | awk '{ for (i=1; i<=NF; i++) if ($i ~ /^[0-9]+$/) { print $i; exit } }')
    fi
    [[ "$BCM_GID" =~ ^[0-9]+$ ]] || {
        operational_failure "BCM returned an unparseable GID for group $group"
        return $?
    }

    nss_output=$("$GETENT" group "$group") || {
        operational_failure "NSS could not resolve group $group"
        return $?
    }
    IFS=: read -r nss_name _ nss_gid _ <<< "$nss_output"
    [[ "$nss_name" == "$group" && "$nss_gid" =~ ^[0-9]+$ ]] || {
        operational_failure "NSS returned an invalid group record for $group"
        return $?
    }
    [[ "$BCM_GID" == "$nss_gid" ]] || {
        operational_failure "BCM/NSS GID mismatch for $group (BCM=$BCM_GID, NSS=$nss_gid)"
        return $?
    }
}

bcm_user_exists() {
    local username=$1 output list_output
    if output=$("$CMSH" -c "user; get $username name" 2>/dev/null) && [[ -n "${output//[[:space:]]/}" ]]; then
        return 0
    fi

    # A successful list distinguishes a genuinely absent object from a BCM
    # connectivity/session failure during the direct lookup.
    list_output=$("$CMSH" -c 'user; list' 2>/dev/null) || return 2
    awk -v wanted="$username" '$1 == wanted { found=1 } END { exit !found }' <<< "$list_output"
}

validate_public_key() {
    local key_line=$1 key_type key_blob key_details bits
    [[ -n "$key_line" && "$key_line" != *$'\n'* && "$key_line" != *$'\r'* ]] || {
        invalid "SSH public key must be one non-empty line"
        return $?
    }
    case "${key_line,,}" in
        *'private key'*|-----begin*|proc-type:*)
            invalid "private key material is not accepted"
            return $?
            ;;
    esac

    IFS=' ' read -r key_type key_blob _ <<< "$key_line"
    [[ -n "$key_type" && -n "$key_blob" ]] || { invalid "malformed SSH public key"; return $?; }
    case "$key_type" in
        ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521|sk-ssh-ed25519@openssh.com|sk-ecdsa-sha2-nistp256@openssh.com) ;;
        *)
            invalid "unsupported key type or key options are present"
            return $?
            ;;
    esac

    KEY_TEMP=$("$MKTEMP" /tmp/tx16k-add-user-key.XXXXXX) || {
        operational_failure "could not create a temporary key-validation file"
        return $?
    }
    "$CHMOD" 0600 "$KEY_TEMP" || { operational_failure "could not secure temporary validation file"; return $?; }
    printf '%s\n' "$key_line" > "$KEY_TEMP" || { operational_failure "could not write temporary validation file"; return $?; }
    key_details=$("$SSH_KEYGEN" -lf "$KEY_TEMP" -E sha256 2>/dev/null) || {
        invalid "ssh-keygen rejected the public key"
        return $?
    }
    IFS=' ' read -r bits KEY_FINGERPRINT _ <<< "$key_details"
    [[ "$bits" =~ ^[0-9]+$ && "$KEY_FINGERPRINT" == SHA256:* ]] || {
        invalid "could not determine the public-key fingerprint"
        return $?
    }
}

cmsh_quote_password() {
    local value=$1
    value=${value//\\/\\\\}
    value=${value//\"/\\\"}
    printf '"%s"' "$value"
}

create_bcm_user() {
    local username=$1 group=$2 gid=$3 quoted_password=""

    # Feed the transaction through stdin so an nvis-group password never
    # appears in cmsh's argv or in shell tracing. Values interpolated here are
    # already constrained by strict allowlists.
    {
        printf 'user\n'
        printf 'add %s\n' "$username"
        printf 'set groupid %s\n' "$gid"
        printf 'set profile %s\n' "$BCM_PROFILE"
        printf 'set disablepasswordssh yes\n'
        printf 'set createsshkey no\n'
        printf 'set homedirectoryoperation yes\n'
        printf 'validate\n'
        printf 'commit -w\n'
    } | "$CMSH" >/dev/null 2>&1
}

poll_nss_identity() {
    local username=$1 deadline record
    deadline=$((SECONDS + 30))
    while (( SECONDS < deadline )); do
        if record=$("$GETENT" passwd "$username"); then
            IFS=: read -r NSS_USERNAME _ NSS_UID NSS_GID _ NSS_HOME _ <<< "$record"
            if [[ "$NSS_USERNAME" == "$username" && "$NSS_UID" =~ ^[0-9]+$ && "$NSS_GID" =~ ^[0-9]+$ && -n "$NSS_HOME" ]]; then
                return 0
            fi
        fi
        sleep 1
    done
    operational_failure "NSS did not return a valid passwd record for $username within 30 seconds"
}

validate_home_path() {
    local username=$1 expected
    expected="$EXPECTED_HOME_ROOT/$username"
    [[ "$NSS_HOME" == "$expected" ]] || {
        operational_failure "unsafe or unexpected NSS home path: $NSS_HOME (expected $expected)"
        return $?
    }
    [[ ! -L "$EXPECTED_HOME_ROOT" && ! -L "$NSS_HOME" ]] || {
        operational_failure "refusing a symlinked home path: $NSS_HOME"
        return $?
    }
    if [[ -e "$NSS_HOME" && ! -d "$NSS_HOME" ]]; then
        operational_failure "home path exists but is not a directory: $NSS_HOME"
        return $?
    fi
}

ensure_home_and_key() {
    local username=$1 key_line=$2 ssh_dir auth_file ownership exact_count fingerprint_output

    validate_home_path "$username" || return $?
    if [[ ! -e "$NSS_HOME" ]]; then
        "$MKHOMEDIR_HELPER" "$username" 0027 /etc/skel || {
            operational_failure "mkhomedir_helper failed for $username"
            return $?
        }
        [[ -d "$NSS_HOME" && ! -L "$NSS_HOME" ]] || {
            operational_failure "home was not safely created at $NSS_HOME"
            return $?
        }
        if ! "$CHOWN" "$NSS_UID:$NSS_GID" "$NSS_HOME" || ! "$CHMOD" 0750 "$NSS_HOME"; then
            operational_failure "could not set home ownership/mode for $NSS_HOME"
            return $?
        fi
    fi

    ownership=$("$STAT" -c '%u:%g' -- "$NSS_HOME") || { operational_failure "could not inspect $NSS_HOME"; return $?; }
    [[ "$ownership" == "$NSS_UID:$NSS_GID" ]] || {
        operational_failure "existing home has unexpected ownership $ownership (expected $NSS_UID:$NSS_GID)"
        return $?
    }

    ssh_dir="$NSS_HOME/.ssh"
    auth_file="$ssh_dir/authorized_keys"
    [[ ! -L "$ssh_dir" && ! -L "$auth_file" ]] || { operational_failure "refusing symlinked SSH paths under $NSS_HOME"; return $?; }
    [[ ! -e "$ssh_dir" || -d "$ssh_dir" ]] || { operational_failure "$ssh_dir exists but is not a directory"; return $?; }
    [[ ! -e "$auth_file" || -f "$auth_file" ]] || { operational_failure "$auth_file exists but is not a regular file"; return $?; }

    "$INSTALL" -d -m 0700 -o "$NSS_UID" -g "$NSS_GID" -- "$ssh_dir" || {
        operational_failure "could not create or secure $ssh_dir"
        return $?
    }
    if [[ ! -e "$auth_file" ]]; then
        "$INSTALL" -m 0600 -o "$NSS_UID" -g "$NSS_GID" /dev/null "$auth_file" || {
            operational_failure "could not create $auth_file"
            return $?
        }
    fi
    if ! "$CHOWN" "$NSS_UID:$NSS_GID" "$auth_file" || ! "$CHMOD" 0600 "$auth_file"; then
        operational_failure "could not secure $auth_file"
        return $?
    fi

    exact_count=0
    while IFS= read -r existing_line || [[ -n "$existing_line" ]]; do
        [[ "$existing_line" == "$key_line" ]] && exact_count=$((exact_count + 1))
    done < "$auth_file"
    if (( exact_count == 0 )); then
        printf '%s\n' "$key_line" >> "$auth_file" || { operational_failure "could not append the SSH public key"; return $?; }
    elif (( exact_count > 1 )); then
        operational_failure "the requested key unexpectedly appears more than once in $auth_file"
        return $?
    fi

    exact_count=0
    while IFS= read -r existing_line || [[ -n "$existing_line" ]]; do
        [[ "$existing_line" == "$key_line" ]] && exact_count=$((exact_count + 1))
    done < "$auth_file"
    [[ "$exact_count" -eq 1 ]] || { operational_failure "exact-key verification failed after installation"; return $?; }
    ownership=$("$STAT" -c '%u:%g:%a' -- "$ssh_dir") || { operational_failure "could not verify $ssh_dir"; return $?; }
    [[ "$ownership" == "$NSS_UID:$NSS_GID:700" ]] || { operational_failure "incorrect ownership or mode on $ssh_dir: $ownership"; return $?; }
    ownership=$("$STAT" -c '%u:%g:%a' -- "$auth_file") || { operational_failure "could not verify $auth_file"; return $?; }
    [[ "$ownership" == "$NSS_UID:$NSS_GID:600" ]] || { operational_failure "incorrect ownership or mode on $auth_file: $ownership"; return $?; }
    fingerprint_output=$("$SSH_KEYGEN" -lf "$KEY_TEMP" -E sha256 2>/dev/null) || { operational_failure "installed-key fingerprint verification failed"; return $?; }
    [[ "$fingerprint_output" == *" $KEY_FINGERPRINT "* ]] || { operational_failure "installed key does not match the confirmed fingerprint"; return $?; }
}

main() {
    if (( $# > 0 )); then
        case "$1" in
            -h|--help) usage; return "$EXIT_OK" ;;
            *) usage >&2; invalid "unexpected argument: $1"; return $? ;;
        esac
    fi

    preflight || return $?
    select_group || return $?
    resolve_group_gid "$SELECTED_GROUP" || return $?

    local username key_line confirmation existing_status expected_home
    IFS= read -r -p 'Lowercase Linux username: ' username || { invalid "could not read username"; return $?; }
    validate_username "$username" || return $?

    if "$GETENT" passwd "$username" >/dev/null; then
        invalid "NSS user already exists: $username"
        return $?
    fi
    bcm_user_exists "$username"
    existing_status=$?
    if (( existing_status == 0 )); then
        invalid "BCM user already exists: $username"
        return $?
    elif (( existing_status == 2 )); then
        operational_failure "BCM user existence check failed"
        return $?
    fi

    IFS= read -r -p 'Complete OpenSSH public-key line: ' key_line || { invalid "could not read SSH public key"; return $?; }
    validate_public_key "$key_line" || return $?
    expected_home="$EXPECTED_HOME_ROOT/$username"
    printf '\nProvisioning summary:\n'
    printf '  Username:        %s\n' "$username"
    printf '  Primary group:   %s (GID %s)\n' "$SELECTED_GROUP" "$BCM_GID"
    printf '  BCM profile:     %s\n' "$BCM_PROFILE"
    printf '  Expected home:   %s\n' "$expected_home"
    printf '  Key fingerprint: %s\n' "$KEY_FINGERPRINT"
    if [[ "$SELECTED_GROUP" == nvis ]]; then
        printf '  Sudo password:   standard nvis password will be set (password SSH remains disabled)\n'
    fi
    IFS= read -r -p "Type 'yes' to create this account: " confirmation || confirmation=""
    if [[ "$confirmation" != yes ]]; then
        printf 'Cancelled; no changes were made.\n'
        return "$EXIT_OK"
    fi

    create_bcm_user "$username" "$SELECTED_GROUP" "$BCM_GID" || {
        operational_failure "BCM user transaction failed; commit success was not confirmed"
        return $?
    }
    BCM_COMMITTED=1

    poll_nss_identity "$username" || return $?
    [[ "$NSS_GID" == "$BCM_GID" ]] || {
        operational_failure "authoritative NSS GID $NSS_GID does not match selected BCM GID $BCM_GID"
        return $?
    }
    ensure_home_and_key "$username" "$key_line" || return $?

    printf 'User %s was created successfully; key fingerprint %s.\n' "$username" "$KEY_FINGERPRINT"
    return "$EXIT_OK"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
