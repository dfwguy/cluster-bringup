#!/bin/bash
# Return success only when scontrol reports no Slurm-managed PIDs locally.
# Any command or output-format failure is treated as busy (fail closed).

set -o nounset

(( $# == 0 )) || exit 1

# Use the cluster's Slurm module rather than the SSH/PAM environment.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH

# shellcheck source=/dev/null
source /etc/profile.d/modules.sh >/dev/null 2>&1 || exit 1
# The caller can already have slurm recorded in LOADEDMODULES while PATH has
# just been reset above.  Purging forces the following load to restore Slurm's
# paths instead of treating it as a no-op.
module purge >/dev/null 2>&1 || exit 1
module load slurm >/dev/null 2>&1 || exit 1

if ! scontrol=$(type -P scontrol) || [[ ! -x $scontrol ]]; then
    exit 1
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
    exit 1
fi

mapfile -t lines <<< "$output"
read -r -a headings <<< "${lines[0]:-}"

if [[ ${headings[0]:-} != PID || ${headings[1]:-} != JOBID ]]; then
    exit 1
fi

for line in "${lines[@]:1}"; do
    if [[ -n ${line//[[:space:]]/} ]]; then
        exit 1
    fi
done

exit 0
