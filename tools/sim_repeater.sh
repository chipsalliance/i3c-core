#!/usr/bin/env bash

SIM_TRIES="${SIM_TRIES:-3}"
RETRY_COOLDOWN=10
TEMP_LOGS="$(mktemp -d)"

function cleanup {
  rm -rf "${TEMP_LOGS}"
}

trap cleanup EXIT

# Needed to propagate the exit code through the pipe to `tee`
set -o pipefail

for (( i=1; i<="${SIM_TRIES}"; i++ )); do
    echo "$@"
    "$@" 2>&1 | tee "${TEMP_LOGS}/${i}"
    RESULT=$?

    if [[ -n "${SIM_RETRY_CONDITION}" && ( $RESULT != 0 || $SIM_RETRY_IGNORE_EXIT_CODE = 1 ) ]]; then
        if grep -E "${SIM_RETRY_CONDITION}" "${TEMP_LOGS}/${i}" &> /dev/null; then
            echo "Retry condition encountered. Retrying in ${RETRY_COOLDOWN}s"
            echo ''
            sleep "${RETRY_COOLDOWN}"
            continue
        fi
    fi

    exit $RESULT
done

echo "Limit of ${SIM_TRIES} tries exceeded. Exiting"
exit 1
