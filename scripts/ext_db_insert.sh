#!/bin/bash

WATCH_EXT="/tmp/.extended_list"
SCRIPT_DIR="/opt/aggregator/aggregator"
PY_INSERT="main.py"

# Activate Python virtual environment
source /opt/aggregator/safesquid_reporting/bin/activate 
touch "${WATCH_EXT}"

while read -r FILE EVENT
do
    echo "INFO: ${LOG_TIME} Programme Info: Watch File: ${EXT_LOG}: ${EVENT}"
    EXT_LOG_FILE=$(cat ${FILE})
    python3 ${SCRIPT_DIR}/${PY_INSERT} insert extended ${EXT_LOG_FILE}
    echo "INFO: Log file ${EXT_LOG_FILE} Inserted into Database"    
done < <(inotifywait -q -e modify -m "${WATCH_EXT}")
