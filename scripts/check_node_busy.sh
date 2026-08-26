#!/bin/bash
# Return success only when scontrol reports no Slurm-managed PIDs locally.
# Any command or output-format failure is treated as busy (fail closed).

set -o nounset

log_denial() {
    # pam_exec's quiet option suppresses helper output, so write the reason to
    # the journal without exposing PIDs or other job details.
    local message

    message="denying unmanaged SSH for user ${PAM_USER:-unknown}: $*"
    if command -v systemd-cat >/dev/null 2>&1 \
        && printf '%s\n' "$message" | systemd-cat -t check_node_busy -p notice
    then
        return
    fi

    logger -p authpriv.notice -t check_node_busy -- "$message" || true
}

deny() {
    log_denial "$*"
    exit 1
}

(( $# == 0 )) || deny 'helper accepts no arguments'

# Use the cluster's Slurm module rather than the SSH/PAM environment.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH

# shellcheck source=/dev/null
source /etc/profile.d/modules.sh >/dev/null 2>&1 || deny 'could not load the Environment Modules shell integration'
# The caller can already have slurm recorded in LOADEDMODULES while PATH has
# just been reset above.  Purging forces the following load to restore Slurm's
# paths instead of treating it as a no-op.
module purge >/dev/null 2>&1 || deny 'could not reset Environment Modules state'
module load slurm >/dev/null 2>&1 || deny 'could not load the Slurm module'

if ! scontrol=$(type -P scontrol) || [[ ! -x $scontrol ]]; then
    deny 'scontrol is unavailable after loading the Slurm module'
fi

readonly scontrol

output=$("$scontrol" listpids 2>&1)
rc=$?

# On an idle node, scontrol uses exit status 1 for this expected response.
# It is not an operational failure: allow the idle-node PAM fallback.
if [[ $rc -eq 1 && $output == 'No job steps exist on this node.' ]]; then
    exit 0
fi

# Any other non-zero result is an unexpected Slurm/query failure.  Deny it.
if [[ $rc -ne 0 ]]; then
    detail=${output//$'\n'/ }
    deny "scontrol listpids failed with exit ${rc}: ${detail:0:200}"
fi

mapfile -t lines <<< "$output"
read -r -a headings <<< "${lines[0]:-}"

if [[ ${headings[0]:-} != PID || ${headings[1]:-} != JOBID ]]; then
    deny 'scontrol listpids returned an unexpected successful response'
fi

for line in "${lines[@]:1}"; do
    if [[ -n ${line//[[:space:]]/} ]]; then
        deny 'the node has local Slurm job steps'
    fi
done

exit 0
