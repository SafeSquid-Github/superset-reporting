#!/bin/bash

WATCH_PERF="/tmp/.performance_list"
SCRIPT_DIR="/opt/aggregator/aggregator"
PY_INSERT="main.py"

# Activate Python virtual environment
source /opt/aggregator/safesquid_reporting/bin/activate 
touch "${WATCH_PERF}"

while read -r FILE EVENT
do
    echo "INFO: ${LOG_TIME} Programme Info: Watch File: ${PERF_LOG}: ${EVENT}"
    PERF_LOG_FILE=$(cat ${FILE})
    python3 ${SCRIPT_DIR}/${PY_INSERT} insert performance ${PERF_LOG_FILE}
    echo "INFO: Log file ${PERF_LOG_FILE} Inserted into Database"    
done < <(inotifywait -q -e modify -m "${WATCH_PERF}")
