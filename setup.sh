#!/bin/bash

# syslog logging
THIS_PROCESS=$BASHPID
TAG="aggregator.setup"

# Redirect output to syslog
if [[ -t 1 ]]; then
    exec 1> >( exec logger --id=${THIS_PROCESS} -s -t "${TAG}" ) 2>&1
else
    exec 1> >( exec logger --id=${THIS_PROCESS} -t "${TAG}" ) 2>&1
fi

# Default values for database and admin settings
PROJECT_DIR="/opt/aggregator"
PGUSER="admin"
PGPASSWORD="safesquid"
PGHOST="127.0.0.1" # Default to localhost
PGPORT="5432" # Default PostgreSQL port
PGDATABASE="safesquid_logs"
ADMIN_USERNAME="admin"
ADMIN_PASSWORD="safesquid"
ADMIN_FIRST_NAME="admin"
ADMIN_LAST_NAME="admin"
ADMIN_EMAIL="admin@mail.com"

# Default directory for the current working directory
CURRENT_DIR=$(pwd)
VENV_NAME="${PROJECT_DIR}/safesquid_reporting"
SERVICE_DIR="${PROJECT_DIR}/etc/systemd/system"
SUPERSET_CONF_DIR="${PROJECT_DIR}/etc/superset"
AGG_CONF_DIR="${PROJECT_DIR}/etc/aggregator"
SCRIPT_DIR="${PROJECT_DIR}/bin"
PG_CONF="${PROJECT_DIR}/etc/postgresql/postgresql.conf"
DATA_DIRECTORY="/var/db/aggregator"
SSH_KEY="id_rsa"
KEY_STORE="/root/.ssh"
RRSYNC="/usr/local/bin/rrsync"
OUR_IP=$(ip a | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1')


# Validate required arguments
[ -z ${OPTARG} ] && echo "INFO: Using default values"

# Move files to project directory and set up directory structure
SETUP_DIR () 
{
	# Create directory structure
	[ ! -d "${SCRIPT_DIR}" ] && mkdir -p "${SCRIPT_DIR}"
	[ ! -d "${SUPERSET_CONF_DIR}" ] && mkdir -p "${SUPERSET_CONF_DIR}"
	[ ! -d "${AGG_CONF_DIR}" ] && mkdir -p "${AGG_CONF_DIR}"

	# Move all script files
	rsync -azv ${CURRENT_DIR}/aggregator/*.py "${SCRIPT_DIR}/"
	rsync -azv ${CURRENT_DIR}/interface/*.sh "${SCRIPT_DIR}/"
	rsync -azv ${CURRENT_DIR}/scripts/* "${SCRIPT_DIR}/"

	# Move all configurations
	rsync -azv ${CURRENT_DIR}/aggregator/*.xml "${AGG_CONF_DIR}/"
	rsync -azv ${CURRENT_DIR}/etc/* "${PROJECT_DIR}/etc/"

	echo "INFO: Project directory synced with latest changes"
	echo "INFO: Setting up permissions"
	chmod 755 "${SCRIPT_DIR}/"* # Set permissions for script files
	echo "INFO: Creating softlinks"
	ln -sf ${SCRIPT_DIR}/*.sh /usr/local/bin/ # Create symbolic links for scripts
}

# Update package list and install necessary system packages
SYS_PACKAGES () 
{
	echo "INFO: Updating your system and installing required packages"
	export DEBIAN_FRONTEND=noninteractive
	apt update && apt upgrade -y
	apt install -y build-essential libssl-dev libffi-dev python3-dev python3-pip python3-venv libsasl2-dev libldap2-dev default-libmysqlclient-dev libpq-dev python3-psycopg2 redis-server postgresql net-tools inotify-tools monit
	apt autoremove -y && apt autoclean -y
	export DEBIAN_FRONTEND=
}

# Get Python 3.10 for systems where the Python version is not 3.10
GET_PYTHON_3_10 () 
{
	export DEBIAN_FRONTEND=noninteractive
	apt install software-properties-common -y
	# Add PPA if not already added
	grep -q "deadsnakes/ppa" /etc/apt/sources.list /etc/apt/sources.list.d/* || add-apt-repository ppa:deadsnakes/ppa -y && echo "INFO: Adding new source for python 3.10 packages"
	apt install python3.10 python3.10-venv python3.10-dev -y
	echo "INFO: Setting python3.10 as default"
	# Update alternatives to set Python 3.10 as default
	update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 1
	# Optionally set python3.10 as default (if desired)
	update-alternatives --set python3 /usr/bin/python3.10
	# Install pip for Python 3.10
	curl -sS https://bootstrap.pypa.io/get-pip.py | python3.10
	apt autoremove -y && apt autoclean -y
	export DEBIAN_FRONTEND=
}

# Check Python version
PY_VERSION_CHECK () 
{
	PY_VERSION=$(python3 --version)
	PY_V="${PY_VERSION#Python }" # Extract the major version number
	PY_V="${PY_V%.*}" # Extract the major version number
	# If Python version is less than 3.10 then upgrade
	# [[ ${PY_V} == '3.10' ]] && echo "INFO: python version OK!" && return 0
	[[ ${PY_V} != '3.10' ]] && GET_PYTHON_3_10
	[[ ${PY_V} == '3.10' ]] && echo "INFO: python version OK!" && return 0
	PY_VERSION=$(python3 --version)
	PY_V="${PY_VERSION#Python }" # Extract the major version number
	PY_V="${PY_V%.*}" # Extract the major version number
	[[ ${PY_V} != '3.10' ]] && echo "INFO: python version not supported, 3.10 is required" && exit 1
}

# Create the virtual environment
CREATE_PY_ENV () 
{
	echo "INFO: Creating virtual environment ${VENV_NAME}."
	[ ! -d "${VENV_NAME}" ] && python3 -m venv ${VENV_NAME}
	source ${VENV_NAME}/bin/activate # Activate the virtual environment
}

# Installation of required Python packages
PY_PACKAGES () 
{
	echo "INFO: Installing python required packages"
	python3 -m pip install --upgrade pip || python3 -m pip install --force-reinstall pip
	python3 -m pip install --quiet --require-virtualenv --requirement requirements.txt
}

# Create PostgreSQL config file
CREATE_PSQL_CONF () 
{
echo "INFO: Creating postgres config file"
cat << _EOL > "${AGG_CONF_DIR}/config.ini"
[database]
username = ${PGUSER}
password = ${PGPASSWORD}
host = ${PGHOST}
port = ${PGPORT}
dbname = ${PGDATABASE}
maxconns = 1
_EOL
}

AGGREGATOR_DB_CREATE () 
{
	local INITDB=$(find /usr/lib/postgresql  -name initdb)
	# Creating a database store for postgres
	[ ! -d ${DATA_DIRECTORY} ] && mkdir -p ${DATA_DIRECTORY}
	chown postgres:postgres ${DATA_DIRECTORY}
	chmod 700 ${DATA_DIRECTORY}
	#Stop postgres service
	systemctl stop postgresql.servic
	#Creating new database
	sudo -u postgres ${INITDB} -D ${DATA_DIRECTORY} -E UTF8 --locale=en_US.UTF-8
	#Restarting service 
	systemctl restart postgresql.service
	echo "INFO: Postgres DB store update -> ${DATA_DIRECTORY}"
}

AGGREGATOR_DB_SETUP () 
{	
	local PG_DATA_DIRECTORY=$(sudo -i -u postgres psql -c "SHOW data_directory;" | grep -E -o '/.*')
	local CONF=$(find /etc/postgresql/ -name postgresql.conf)
	local DB_EXISTS=$(sudo -i -u postgres psql -t -c "SELECT 1 FROM pg_database WHERE datname = "\'${PGDATABASE}\'";" | tr -d '[:space:]')

	[ -z "${PG_DATA_DIRECTORY}" ] && echo "INFO: DB not found" && AGGREGATOR_DB_CREATE
	[ "${PG_DATA_DIRECTORY}" != "${DATA_DIRECTORY}" ] && AGGREGATOR_DB_CREATE
	[ -z "${DB_EXISTS}" ] && sudo -i -u postgres psql -c "CREATE DATABASE ${PGDATABASE} OWNER ${PGUSER};"

	local PG_DATA_DIRECTORY=$(sudo -i -u postgres psql -c "SHOW data_directory;" | grep -E -o '/.*')
	[ "${PG_DATA_DIRECTORY}" == "${DATA_DIRECTORY}" ] && echo "INFO: DB Exists -> ${DATA_DIRECTORY}" && return 0

	#Update the configuration
	sed -i "s|^data_directory = .*|data_directory = '/var/db/aggregator'|" ${CONF}
	systemctl start postgresql.service
	sudo -u postgres psql -d ${PGDATABASE} -c "SELECT pg_reload_conf();" || return 1 
}

# Setup PostgreSQL
SETUP_PSQL () 
{	
	local EXIT_CODE
	# Export the PostgreSQL connection details as environment variables
	export PGPASSWORD=${PGPASSWORD}
	# Create PostgreSQL config.ini file
	CREATE_PSQL_CONF
	# Create a new user
	echo "INFO: Creating new user ${PGUSER}"
	sudo -i -u postgres psql -c "CREATE USER ${PGUSER} WITH PASSWORD "\'${PGPASSWORD}\'";"
	#Change the default DB store location
	AGGREGATOR_DB_SETUP || return 1
	# Create database
	echo "INFO: Creating new database ${PGDATABASE}"
	sudo -i -u postgres psql -c "CREATE DATABASE ${PGDATABASE} OWNER ${PGUSER};"
	# Connect to the PostgreSQL database
	echo "INFO: Connecting to the PostgreSQL database"
	psql -h localhost -U ${PGUSER} -d ${PGDATABASE} -c "SELECT 1;" &>/dev/null
	EXIT_CODE=${?}
	[ ${EXIT_CODE} == 0 ] && echo "INFO: Database ${PGDATABASE} created successfully."
	[ ${EXIT_CODE} != 0 ] && echo "INFO: Database ${PGDATABASE} already exists or an error occurred."
}

# Create a .env file with specified environment variables
CREATE_FLASK_ENV () 
{
	echo "export FLASK_APP=superset" > ${SUPERSET_CONF_DIR}/.env
	echo "export SUPERSET_CONFIG_PATH=${SUPERSET_CONF_DIR}/superset_config.py" >> ${SUPERSET_CONF_DIR}/.env
	# Load the .env file
	source ${SUPERSET_CONF_DIR}/.env
	echo "INFO: Created interface/.env file with environment variables and loaded"
}

# Generate a secret key using openssl and store it in superset_config.py
CREATE_SUPERSET_CONFIG_PY () 
{
	[ -f "${SUPERSET_CONF_DIR}/superset_config.py" ] && return 1
	SECRET_KEY=$(openssl rand -base64 42)
	echo "SECRET_KEY = '${SECRET_KEY}'" > ${SUPERSET_CONF_DIR}/superset_config.py
	chmod 644 ${SUPERSET_CONF_DIR}/superset_config.py
	echo "INFO: Generated and stored SECRET_KEY in ${SUPERSET_CONF_DIR}/superset_config.py"
}

# Create a service for Superset
SUPERSET_SERVICE () 
{
echo "INFO: Creating a service for superset"
[ ! -d "${SERVICE_DIR}" ] && mkdir -p ${SERVICE_DIR}
cat << _EOL > ${SERVICE_DIR}/superset.service
[Unit]
Description=Superset
After=network.target

[Service]
User=root
Group=root
WorkingDirectory=${SCRIPT_DIR}/
ExecStart=/bin/bash -c 'source ${PROJECT_DIR}/safesquid_reporting/bin/activate && /bin/bash ${SCRIPT_DIR}/run.sh -d'
ExecStop=deactive
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
_EOL

	ln -sf ${SERVICE_DIR}/superset.service /etc/systemd/system/
	[ -f "/etc/systemd/system/superset.service" ] && systemctl daemon-reload
	systemctl enable superset.service && systemctl start superset.service
}

# Setup Superset
SETUP_SUPERSET () 
{
	CREATE_FLASK_ENV
	CREATE_SUPERSET_CONFIG_PY
	echo "INFO: Setting up superset"
	SUPERSET_BIN="$(which superset)"
	[ -z ${SUPERSET_BIN} ] && echo "ERROR: Superset not found" && return 1
	# Superset DB upgrade
	superset db upgrade || return 1
	# Superset FAB create-admin
	superset fab create-admin --username ${ADMIN_USERNAME} --firstname ${ADMIN_FIRST_NAME} --lastname ${ADMIN_LAST_NAME} --email ${ADMIN_EMAIL} --password ${ADMIN_PASSWORD} || return 1
	# Superset init
	echo "INFO: Initializing superset"
	superset init && echo "INFO: All tasks completed successfully." || return 1
	SUPERSET_SERVICE
}

# Create databases
DB_CREATE () 
{
	echo "INFO: Creating database: {extended,performance,csp}"
	local TABLE_EXT_EXISTS=$(sudo -i -u postgres psql -d  "${PGDATABASE}" -t -c "SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'extended_logs';" | tr -d '[:space:]')
	local TABLE_PERF_EXISTS=$(sudo -i -u postgres psql -d  "${PGDATABASE}" -t -c "SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'performance_logs';" | tr -d '[:space:]')
	local TABLE_CSP_EXISTS=$(sudo -i -u postgres psql -d  "${PGDATABASE}" -t -c "SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'csp_logs';" | tr -d '[:space:]')
	[ -z ${TABLE_EXT_EXISTS} ] && python3 ${SCRIPT_DIR}/main.py create-database extended
	[ -z ${TABLE_PERF_EXISTS} ] && python3 ${SCRIPT_DIR}/main.py create-database performance
	[ -z ${TABLE_CSP_EXISTS} ] && python3 ${SCRIPT_DIR}/main.py create-database csp
}

GEN_SSH_KEY()
{
	[ "x${KEY_STORE}" == "x" ] && echo "undefined: KEY_STORE " && return;
	[ "x${SSH_KEY}" == "x" ] && echo "undefined: SSH_KEY"  && return;
	[ -f "${KEY_STORE}/${SSH_KEY}" ] && echo "already exists: ${KEY_STORE}/${SSH_KEY}" && return;
	[ ! -d "${KEY_STORE}" ] && mkdir -p "${KEY_STORE}"  ;
	ssh-keygen -t rsa -b 4096 -C "aggregator@${OUR_IP}" -f ${KEY_STORE}/${SSH_KEY} -N "" 
}

MONIT_PAM()
{
	[ -f /etc/pam.d/monit ] && echo "already exists: /etc/pam.d/monit" && return 0;
	cat <<- _EOF > /etc/pam.d/monit 
	# monit: auth account password session
	auth       sufficient     pam_securityserver.so
	auth       sufficient     pam_unix.so
	auth       required       pam_deny.so
	account    required       pam_permit.so
	_EOF
}

MONIT_SETUP()
{
	for MONIT_CONF in $(find ${PROJECT_DIR}/etc/monit/conf.d/*.monit -type f)
	do
		ln -vfs ${MONIT_CONF} /etc/monit/conf.d/ 
	done
	monit reload 
}

SHARE_AUTHORIZATION()
{
	local AUTHORIZATION=
	
	[ ! -f "${KEY_STORE}/${SSH_KEY}.pub" ] && echo "not found: ${KEY_STORE}/${SSH_KEY}.pub" && return 1;
	
	AUTHORIZATION="command="
	AUTHORIZATION+='"'
	AUTHORIZATION+="${RRSYNC} -ro /var/log/safesquid"
	AUTHORIZATION+='"'
	AUTHORIZATION+=' '
	AUTHORIZATION+=`<${KEY_STORE}/${SSH_KEY}.pub`
	cat <<- _EOF > "${PROJECT_DIR}/setup_authorized_keys" 
	# The following directive in /root/.ssh/authorized_keys of your SafeSquid proxy servers enables aggregator to sync log files
	${AUTHORIZATION}
	_EOF
}

# Display information after setup
INFO () {

	echo ""
	echo "Manual Setup Required"
	echo "Copy the content below into the /root/.ssh/authorized_keys file on your SafeSquid proxy servers to enable the aggregator to sync log files."
	cat "${PROJECT_DIR}/setup_authorized_keys"
	echo ""
	echo "Copy the rrsync binary from ${PROJECT_DIR}/bin/rrsync to your SafeSquid proxy servers at /usr/local/bin/rrsync."
	echo ""
}

# Main function to execute the script
MAIN () 
{
	SETUP_DIR
	SYS_PACKAGES
	PY_VERSION_CHECK
	CREATE_PY_ENV
	PY_PACKAGES
	SETUP_PSQL
	SETUP_SUPERSET
	GEN_SSH_KEY
	SHARE_AUTHORIZATION
	MONIT_PAM
	MONIT_SETUP
	INFO
}

# Function to print the usage of the script
usage() 
{
  echo "Usage: $0 [-u PGUSER] [-p PGPASSWORD] [-H PGHOST] [-P PGPORT] [-d PGDATABASE] [-a ADMIN_USERNAME] [-w ADMIN_PASSWORD] [-f ADMIN_FIRST_NAME] [-l ADMIN_LAST_NAME] [-e ADMIN_EMAIL][-D DIRECTORY_NAME] [-v VENV_NAME]"
  exit 1
}

# Parse command-line arguments
while getopts "u:p:H:P:d:a:w:f:l:e:D:v:h" opt
do
  case $opt in
	u) PGUSER=${OPTARG} ;;  # Set PostgreSQL username
	p) PGPASSWORD=${OPTARG} ;;  # Set PostgreSQL password
	H) PGHOST=${OPTARG} ;;  # Set PostgreSQL host
	P) PGPORT=${OPTARG} ;;  # Set PostgreSQL port
	d) PGDATABASE=${OPTARG} ;;  # Set PostgreSQL database name
	a) ADMIN_USERNAME=${OPTARG} ;;  # Set admin username
	w) ADMIN_PASSWORD=${OPTARG} ;;  # Set admin password
	f) ADMIN_FIRST_NAME=${OPTARG} ;;  # Set admin first name
	l) ADMIN_LAST_NAME=${OPTARG} ;;  # Set admin last name
	e) ADMIN_EMAIL=${OPTARG} ;;  # Set admin email
	D) PROJECT_DIR=${OPTARG} ;;  # Set project directory
	v) VENV_NAME=${PROJECT_DIR}/${OPTARG} ;;  # Set virtual environment name
	h) usage ;;  # Display usage information
	*) usage ;;  # Display usage information for invalid options
  esac
done

# Execute the main function
MAIN
