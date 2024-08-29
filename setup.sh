#!/bin/bash

# syslog logging
# THIS_PROCESS=$BASHPID
# TAG="aggregator.setup"

# # Redirect output to syslog
# if [[ -t 1 ]]; then
#     exec 1> >( exec logger --id=${THIS_PROCESS} -s -t "${TAG}" ) 2>&1
# else
#     exec 1> >( exec logger --id=${THIS_PROCESS} -t "${TAG}" ) 2>&1
# fi

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
PG_DB="/var/db/aggregator"

# Validate required arguments
[ -z ${OPTARG} ] && echo "INFO: Using default values"

# Update package list and install necessary system packages
SYS_PACKAGES () {

	echo "INFO: Updating your system and installing required packages"
	apt -qq update && apt -qq upgrade -y
	apt -qq install -y build-essential libssl-dev libffi-dev python3-dev python3-pip python3-venv libsasl2-dev libldap2-dev default-libmysqlclient-dev libpq-dev python3-psycopg2 redis-server postgresql net-tools inotify-tools
}

# Get Python 3.10 for systems where the Python version is not 3.10
GET_PYTHON_3_10 () {

	apt -qq install software-properties-common -y
	# Add PPA if not already added
	grep -q "deadsnakes/ppa" /etc/apt/sources.list /etc/apt/sources.list.d/* || add-apt-repository ppa:deadsnakes/ppa -y && echo "INFO: Adding new source for python 3.10 packages"
	apt -qq install python3.10 python3.10-venv python3.10-dev -y
	echo "INFO: Setting python3.10 as default"
	# Update alternatives to set Python 3.10 as default
	update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 1
	# Optionally set python3.10 as default (if desired)
	update-alternatives --set python3 /usr/bin/python3.10
	# Install pip for Python 3.10
	curl -sS https://bootstrap.pypa.io/get-pip.py | python3.10
}

# Check Python version
PY_VERSION_CHECK () {

	PY_VERSION=$(python3 --version)
	PY_V=${PY_VERSION#*.} # Extract the major version number
	# If Python version is less than 3.10 then upgrade
	[[ ${PY_V} != 3.10 ]] && GET_PYTHON_3_10
	PY_VERSION=$(python3 --version)
	PY_V=${PY_VERSION#*.}
	[[ ${PY_V} != 3.10 ]] && echo "INFO: python version not supported, 3.10 is required" && return 1
}

# Move files to project directory and set up directory structure
SETUP_DIR () {

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
	rsync -azv ${PROJECT_DIR}/etc/rsyslog.d/* /etc/rsyslog.d/

	echo "INFO: Project directory synced with latest changes"
	echo "INFO: Setting up permissions"
	chmod 755 "${SCRIPT_DIR}/"* # Set permissions for script files
	echo "INFO: Creating softlinks"
	ln -sf ${SCRIPT_DIR}/*.sh /usr/local/bin/ # Create symbolic links for scripts
}

# Disable AppArmor enforcement for rsyslog
DISABLE_APPARMOR_RSYSLOG () {

	echo "INFO: Disabling Apparmor for rsyslogd"
	ln -fs /etc/apparmor.d/usr.sbin.rsyslogd /etc/apparmor.d/disable/
	[ ! -f "/etc/apparmor.d/disable/usr.sbin.rsyslogd" ] && apparmor_parser -R /etc/apparmor.d/usr.sbin.rsyslogd
}

# Configure rsyslog
RSYSLOG_CONFIG () {

	local EXIT_CODE
	echo "INFO: Setting up rsyslog"
	rsync -azv "${SCRIPT_DIR}/log_rotate.sh" /usr/local/bin/
	echo "INFO: Rsyslog configuration check"
	rsyslogd -N1 -f /etc/rsyslog.d/aggregator.conf &> /dev/null
	EXIT_CODE="${?}"
	[ ${EXIT_CODE} == "1" ] && echo "ERROR: SYSLOG CONF: /etc/rsyslog.d/aggregator.conf: INVALID Config" && return
	echo "INFO: Performing rsyslog service restart"
	systemctl restart rsyslog.service
	echo "INFO: Disabling Apparmor for rsyslog"
	DISABLE_APPARMOR_RSYSLOG
}

# Generate a secret key using openssl and store it in superset_config.py
CREATE_SUPERSET_CONFIG_PY () {

	SECRET_KEY=$(openssl rand -base64 42)
	echo "SECRET_KEY = '${SECRET_KEY}'" > ${SUPERSET_CONF_DIR}/superset_config.py
	chmod 644 ${SUPERSET_CONF_DIR}/superset_config.py
	echo "INFO: Generated and stored SECRET_KEY in ${SUPERSET_CONF_DIR}/superset_config.py"
}

# Create the virtual environment
CREATE_PY_ENV () {

	echo "INFO: Creating virtual environment ${VENV_NAME}."
	[ ! -d "${VENV_NAME}" ] && python3 -m venv ${VENV_NAME}
	source ${VENV_NAME}/bin/activate # Activate the virtual environment
}

# Create a .env file with specified environment variables
CREATE_FLASK_ENV () {

	echo "export FLASK_APP=superset" > ${SUPERSET_CONF_DIR}/.env
	echo "export SUPERSET_CONFIG_PATH=${SUPERSET_CONF_DIR}/superset_config.py" >> ${SUPERSET_CONF_DIR}/.env
	# Load the .env file
	source ${SUPERSET_CONF_DIR}/.env
	echo "INFO: Created interface/.env file with environment variables and loaded"
}

# Create PostgreSQL config file
CREATE_PSQL_CONF () {

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

PG_DB_SETUP () {
	
	echo "INFO: Postgres DB store update -> ${PG_DB}"
	local DB=$(sudo -i -u postgres psql -c "SHOW data_directory;" | grep -E -o '/.*')
	local CONF=$(find /etc/postgresql/ -name postgresql.conf)

	[ -z "${DB}" ] && echo "INFO: DB not found" && return 1 
	[ "${DB}" == "${PG_DB}" ] && echo "INFO: DB Exists -> ${PG_DB}" && return 0
	#Stop postgres service
	systemctl stop postgresql
	#Update the configuration
	ln -sf ${PG_CONF} ${CONF}
	# Creating a database store for postgres
	[ ! -d ${PG_DB} ] && mkdir -p ${PG_DB}
	chown postgres:postgres ${PG_DB}
	chmod 700 ${PG_DB}
	#Start postgres service
	systemctl start postgresql
	sudo -u postgres /usr/lib/postgresql/16/bin/initdb -D ${PG_DB} -E UTF8 --locale=en_US.UTF-8
}

# Setup PostgreSQL
SETUP_PSQL () {

	local EXIT_CODE
	# Export the PostgreSQL connection details as environment variables
	export PGPASSWORD=${PGPASSWORD}
	# Create PostgreSQL config.ini file
	CREATE_PSQL_CONF
	#Change the default DB store location
	PG_DB_SETUP || return 1
	# Create a new user
	echo "INFO: Creating new user ${PGUSER}"
	sudo -i -u postgres psql -c "CREATE USER ${PGUSER} WITH PASSWORD "\'${PGPASSWORD}\'";"
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

# Create Redis config file
CREATE_REDIS_CONF () {

	echo "INFO: Creating redis config file"
cat << _EOL >> ${SUPERSET_CONF_DIR}/config.ini
from redis import StrictRedis

# Redis configuration
REDIS_HOST = 'localhost'
REDIS_PORT = 6379
REDIS_DB = 0

# Redis URI
REDIS_URI = f"redis://{REDIS_HOST}:{REDIS_PORT}/{REDIS_DB}"

# Configure Flask-Limiter to use Redis
SUPERSET_FLASK_LIMTER_STORAGE_URI = REDIS_URI

# Example of setting up other Redis-based configurations for Superset
RESULTS_BACKEND = RedisCache(
  host=REDIS_HOST,
  port=REDIS_PORT,
  key_prefix='superset_results'  # Optional: You can configure the cache as well
)

CACHE_CONFIG = {
  'CACHE_TYPE': 'RedisCache',
  'CACHE_DEFAULT_TIMEOUT': 300,
  'CACHE_KEY_PREFIX': 'superset_',
  'CACHE_REDIS_HOST': REDIS_HOST,
  'CACHE_REDIS_PORT': REDIS_PORT,
  'CACHE_REDIS_DB': REDIS_DB,
}
_EOL
	echo "INFO: Created config.ini file with the specified content."
}

# Installation of required Python packages
PY_PACKAGES () {

	echo "INFO: Installing python required packages"
	python3 -m pip install --upgrade pip || python3 -m pip install --force-reinstall pip
	python3 -m pip install --quiet --require-virtualenv --requirement requirements.txt
}

# Setup Superset
SETUP_SUPERSET () {

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
}

# Create a service for Superset
SUPERSET_SERVICE () {

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
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
_EOL

	ln -sf ${SERVICE_DIR}/superset.service /etc/systemd/system/
	[ -f "/etc/systemd/system/superset.service" ] && systemctl daemon-reload
	systemctl enable superset.service && systemctl start superset.service
}

# Create databases
DB_CREATE () {

	echo "INFO: Creating database: {extended,performance}"
	python3 ${SCRIPT_DIR}/main.py create-database extended
	python3 ${SCRIPT_DIR}/main.py create-database performance
}

# Create a service for DB Insertion
DB_INSERT_SERVICE () {

	echo "INFO: Creating a service for DB Insertion extended"
cat << _EOL > ${SERVICE_DIR}/superset_db_insert_ext.service
[Unit]
Description=Superset.DB.Insert.ext
After=network.target

[Service]
User=root
Group=root
ExecStart=/bin/bash ${SCRIPT_DIR}/ext_db_insert.sh
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
_EOL
  echo "INFO: Creating a service for DB Insertion performance"
  cat << _EOL > ${SERVICE_DIR}/superset_db_insert_perf.service
[Unit]
Description=Superset.DB.Insert.perf
After=network.target

[Service]
User=root
Group=root
ExecStart=/bin/bash ${SCRIPT_DIR}/perf_db_insert.sh
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
_EOL

	ln -sf ${SERVICE_DIR}/superset_db_insert_ext.service /etc/systemd/system/
	ln -sf ${SERVICE_DIR}/superset_db_insert_perf.service /etc/systemd/system/

	[ -f "/etc/systemd/system/superset_db_insert_ext.service " ] && systemctl daemon-reload
	[ -f "/etc/systemd/system/superset_db_insert_perf.service " ] && systemctl daemon-reload

	systemctl enable superset_db_insert_ext.service && systemctl start superset_db_insert_ext.service
	systemctl enable superset_db_insert_perf.service && systemctl start superset_db_insert_perf.service
}

# Display information after setup
INFO () {

	echo ""
	echo "INFO: To activate your virtual environment execute below command."
	echo "source ${PROJECT_DIR}/safesquid_reporting/bin/activate"
	echo ""
	echo "You'll be required to activate your virtual environment while importing data into your database manually"
}

# Main function to execute the script
MAIN () {

	SYS_PACKAGES
	PY_VERSION_CHECK
	SETUP_DIR
	PY_PACKAGES
	RSYSLOG_CONFIG
	SETUP_PSQL
	CREATE_SUPERSET_CONFIG_PY
	CREATE_PY_ENV
	CREATE_FLASK_ENV
	SETUP_SUPERSET
	SUPERSET_SERVICE
	DB_CREATE
	DB_INSERT_SERVICE
	INFO
}

# Function to print the usage of the script
usage() {

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