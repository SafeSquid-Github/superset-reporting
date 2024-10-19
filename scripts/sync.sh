#!/bin/bash

THIS_PROCESS=$BASHPID
TAG="aggregator.sync"
if [[ -t 1 ]]; then
    exec 1> >( exec logger --id=${THIS_PROCESS} -s -t "${TAG}" ) 2>&1
else
    exec 1> >( exec logger --id=${THIS_PROCESS} -t "${TAG}" ) 2>&1
fi

# list of IPs of SafeSquid Proxy Servers
SERVERS_LIST="/opt/aggregator/servers.list"
LOCAL_HOST="localhost"

LOCAL_AGGREGATOR_DIRECTORY="/var/log/aggregator/safesquid"
REMOTE_LOG_DIRECTORY="/var/log/safesquid"
ACCESS_LOG_SUB_FOLDER="access"
REPORT_TRIGGER="/var/log/aggregator/trigger"
SSH_KEY="id_rsa"
KEY_STORE="/root/.ssh"
SYNC_USER="root"

LOG_TYPE=(extended)
LOG_TYPE+=(performance)
LOG_TYPE+=(csp)

SERVERS=();

GET_SERVERS()
{
	local COMMENT="#*"
	while read -r SNAME
	do
		SERVERS+=(${SNAME%%${COMMENT}})
	done < "${SERVERS_LIST}"	
}


RSYNC_COMMAND="/usr/bin/rsync"
# LOG_CONVERTOR="/usr/local/bin/log_convert"
LOG="/var/log/sync.log"
# NEW_LOG="N"

CHECK_FOLDERS()
{

	[ "x${LOCAL_AGGREGATOR_DIRECTORY}" == "x" ] && echo "error: unspecified: LOCAL_AGGREGATOR_DIRECTORY" && exit 1
	[ ! -d "${LOCAL_AGGREGATOR_DIRECTORY}" ] && mkdir -p "${LOCAL_AGGREGATOR_DIRECTORY}"
	[ ! -d "${LOCAL_AGGREGATOR_DIRECTORY}" ] && echo "error: creating: AGGREGATOR_DIRECTORY: ${LOCAL_AGGREGATOR_DIRECTORY}" && exit 1
}

START_SYNC()
{
	s=${#SERVERS[@]}
	for (( i=0; i<s; i++))
	do
		for LOG_DIR in ${LOG_TYPE[*]}
		do 
			local RSYNC=();
			local SOURCE=${SERVERS[$i]}
			[ "x${SOURCE}" == "x${LOCAL_HOST}" ] && echo "info: log_file: Use local log files" && continue
			local DEST="${LOCAL_AGGREGATOR_DIRECTORY}/${SOURCE}/${LOG_DIR}"

			[ ! -d "${DEST}" ] && mkdir -p "${DEST}"
			[ ! -d "${DEST}" ] && echo "failed to create: ${DEST}" && continue;
			# mkdir -p "${LOCAL_AGGREGATOR_DIRECTORY}/${SOURCE}/${ACCESS_LOG_SUB_FOLDER}"
			
			RSYNC+=("$(which rsync)")
			RSYNC+=("--append")
			RSYNC+=("--compress")
			RSYNC+=("--times")
			RSYNC+=("--archive")
			RSYNC+=("--recursive")
			RSYNC+=("--no-links")
			RSYNC+=("--info=FLIST")
			RSYNC+=("--include=*${LOG_DIR}.log")
			RSYNC+=("--log-file=${DEST}/.journal")
			RSYNC+=("--verbose")
			echo "${RSYNC[*]} -e "ssh -i ${KEY_STORE}/${SSH_KEY}" ${SYNC_USER}@${SOURCE}:${LOG_DIR}/ "${DEST}""
			"${RSYNC[@]}" -e "ssh -i ${KEY_STORE}/${SSH_KEY}" "${SYNC_USER}@${SOURCE}":"${LOG_DIR}/" "${DEST}"
			echo "RSYNC: $SOURCE: $?"
		done
	done
}


MAIN()
{
	date >> ${LOG}
	GET_SERVERS
	CHECK_FOLDERS
	START_SYNC
}

MAIN
# rsync --append -zta --no-links -vze ssh root@192.168.250.148:/var/log/safesquid/extended/ /home/nonsense/