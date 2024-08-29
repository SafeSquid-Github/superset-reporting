#!/bin/bash

# Directory passed as an argument
BASE_DIR="${1}"
LOG="${2}"
[ "${#}" == '0' ] && echo "ERROR: No Input" exit 1
SCRIPT_DIR="/opt/aggregator/aggregator"
PY_INSERT="main.py"
LOG_FILE_NAME="${LOG}.log"
OUT_FILE="/tmp/.${LOG}_list"

# Find extended log files and process them
for LOGFILE in "${BASE_DIR}/${LOG}/*/${LOG_FILE_NAME}"
do
    LOG_DIR="$(dirname "${LOGFILE}")"
    NOW="$(date +"%Y%m%d%H%M%S")"
    MAX_SIZE="$((100 * 1024 * 1024))" #100MB

    # Check if the log file exists
    [ ! -f ${LOGFILE} ] && continue

    # Get the current size
    CURRENT_SIZE="$(stat -c %s ${LOGFILE})"

    [ "${CURRENT_SIZE}" -le "${MAX_SIZE}" ] && continue

    # Rotate the log file
    mv "${LOGFILE}" "${LOG_DIR}/${NOW}-${LOG_FILE_NAME}"
    echo "${LOG_DIR}/${NOW}-${LOG_FILE_NAME}" > "${OUT_FILE}"
done