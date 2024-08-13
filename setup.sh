#!/bin/bash

# Function to print the usage of the script
usage() {
  echo "Usage: $0 [-u PGUSER] [-p PGPASSWORD] [-H PGHOST] [-P PGPORT] [-d PGDATABASE] [-a ADMIN_USERNAME] [-w ADMIN_PASSWORD] [-f ADMIN_FIRST_NAME] [-l ADMIN_LAST_NAME] [-e ADMIN_EMAIL][-D DIRECTORY_NAME] [-v VENV_NAME]"
  exit 1
}

# Default values
PROJECT_DIR="/opt/aggregator/superset"
PGUSER="admin"
PGPASSWORD="safesquid"
PGHOST="127.0.0.1"  # Default to localhost
PGPORT="5432"        # Default PostgreSQL port
PGDATABASE="safesquid_logs"
ADMIN_USERNAME="admin"
ADMIN_PASSWORD="safesquid"
ADMIN_FIRST_NAME="admin"
ADMIN_LAST_NAME="admin"
ADMIN_EMAIL="admin@mail.com"
VENV_NAME="${PROJECT_DIR}/safesquid_reporting"

CURRENT_DIR=$(pwd)

# Parse command-line arguments
while getopts "u:p:H:P:d:a:w:f:l:e:D:v:h" opt; do
  case $opt in
    u) PGUSER=${OPTARG} ;;
    p) PGPASSWORD=${OPTARG} ;;
    H) PGHOST=${OPTARG} ;;
    P) PGPORT=${OPTARG} ;;
    d) PGDATABASE=${OPTARG} ;;
    a) ADMIN_USERNAME=${OPTARG} ;;
    w) ADMIN_PASSWORD=${OPTARG} ;;
    f) ADMIN_FIRST_NAME=${OPTARG} ;;
    l) ADMIN_LAST_NAME=${OPTARG} ;;
    e) ADMIN_EMAIL=${OPTARG} ;;
    d) PROJECT_DIR=${OPTARG} ;;
    v) VENV_NAME=${OPTARG} ;;
    h) usage ;;
    *) usage ;;
  esac
done

# Validate required arguments
[ -z ${OPTARG} ] && echo "INFO: Using default values" 

#Update package list
#Install necessary system packages
SYS_PACKAGES () {

  echo "INFO: Updating your system and installing required packages"
  
  apt -qq update && apt -qq upgrade -y
  apt -qq install -y build-essential libssl-dev libffi-dev python3-dev python3-pip python3-venv libsasl2-dev libldap2-dev default-libmysqlclient-dev libpq-dev python3-psycopg2 redis-server postgresql
}

#Check python version
PY_VERSION_CHECK () {

  PY_VERSION=$(python3 --version | awk '{print $2}')
  PY_V_MAJOR=$(echo ${PY_VERSION} | cut -d. -f1)
  PY_V_MINOR=$(echo ${PY_VERSION} | cut -d. -f2)
}

#Get python3.10 
GET_PYTHON_3_10 () {

  apt -qq install software-properties-common -y
  #Add PPA if not already added
  grep -q "deadsnakes/ppa" /etc/apt/sources.list /etc/apt/sources.list.d/* || add-apt-repository ppa:deadsnakes/ppa -y && echo "INFO: Adding new source for python 3.10 packages"
  apt -qq update 
  apt -qq install python3.10 python3.10-venv python3.10-dev -y

  echo "INFO: Setting python3.10 as default"

  #Update alternatives to set Python 3.10 as default
  update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 1
  #Optionally set python3.10 as default (if desired)
  update-alternatives --set python3 /usr/bin/python3.10
  #Install pip for Python 3.10
  curl -sS https://bootstrap.pypa.io/get-pip.py | python3.10
}

#Directory where the virtual environment will be created
#Create the virtual environment
CREATE_PY_ENV () {

  echo "INFO: Creating virtual environment ${VENV_NAME}."

  [ ! -d "${VENV_NAME}" ] && python3 -m venv ${VENV_NAME}
  source ${VENV_NAME}/bin/activate
}

#Installation of requirements
PY_PACKAGES () {

  echo "INFO: Installing python requried packages"

  pip install --upgrade pip || python3 -m pip install --force-reinstall pip
  pip install -r requirements.txt
}

#Move files to project directory.
SETUP_DIR () {

  rsync -azv ${CURRENT_DIR}/aggregator ${PROJECT_DIR}
  rsync -azv ${CURRENT_DIR}/interface ${PROJECT_DIR}

  echo "INFO: Project directory synced with latest changes"
}

#enerate a secret key using openssl rand -base64 42 and store it in superset_config.py
CREATE_SUPERSET_CONFIG_PY () {

  SECRET_KEY=$(openssl rand -base64 42)

  echo "SECRET_KEY = '${SECRET_KEY}'" > ${PROJECT_DIR}/interface/superset_config.py
  chmod 644 ${PROJECT_DIR}/interface/superset_config.py

  echo "INFO: Generated and stored SECRET_KEY in interface/superset_config.py"
}

#Create a .env file with specified environment variables
CREATE_FLASK_ENV () {

  echo "export FLASK_APP=superset" > ${PROJECT_DIR}/interface/.env
  echo "export SUPERSET_CONFIG_PATH=${PROJECT_DIR}/interface/superset_config.py" >> ${PROJECT_DIR}/interface/.env
  #Load the .env file
  source ${PROJECT_DIR}/interface/.env

  echo "INFO: Created interface/.env file with environment variables and loaded"
}

SETUP_PSQL () {

  local EXIT_CODE
  #Export the PostgreSQL connection details as environment variables
  local export PGPASSWORD=${PGPASSWORD}

  #Create a new user
  echo "INFO: Creating new user ${PGUSER}"
  sudo -i -u postgres psql -c "CREATE USER ${PGUSER} WITH PASSWORD "\'${PGPASSWORD}\'";"
  #Create database 
  echo "INFO: Creating new database ${PGDATABASE}"
  sudo -i -u postgres psql -c "CREATE DATABASE ${PGDATABASE} OWNER ${PGUSER};"

  #Connect to the PostgreSQL database
  echo "INFO: Connecting to the PostgreSQL database"
  psql -h localhost -U ${PGUSER} -d ${PGDATABASE} -c "SELECT 1;" &>/dev/null

  EXIT_CODE=${?}

  [ ${EXIT_CODE} == 0 ] && echo "INFO: Database ${PGDATABASE} created successfully."
  [ ${EXIT_CODE} != 0 ] && echo "INFO: Database ${PGDATABASE} already exists or an error occurred."
}

CREATE_PSQL_CONF () {

echo "INFO: Creating postgres config file"
cat << _EOL > ${PROJECT_DIR}/aggregator/config.ini
[database]
username = ${PGUSER}
password = ${PGPASSWORD}
host = ${PGHOST}
port = ${PGPORT}
dbname = ${PGDATABASE}
maxconns = 1
_EOL
} 

CREATE_REDIS_CONF () {

echo "INFO: Creating redis config file"

cat << _EOL >> ${PROJECT_DIR}/aggregator/config.ini
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
    host=REDIS_HOST, port=REDIS_PORT, key_prefix='superset_results'
)
 
# Optional: You can configure the cache as well
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

SETUP_SUPERSET () {

echo "INFO: Setting up superset"
SUPERSET_BIN="$(which superset)"

[ -z ${SUPERSET_BIN} ] && echo "ERROR: Superset not found" && return 1
#Superset DB upgrade
superset db upgrade || return 1
#Superset FAB create-admin
superset fab create-admin --username ${ADMIN_USERNAME} --firstname ${ADMIN_FIRST_NAME} --lastname ${ADMIN_LAST_NAME} --email ${ADMIN_EMAIL} --password ${ADMIN_PASSWORD} || return 1
#Superset init

echo "INFO: Intiallizing superset"
superset init && echo "INFO: All tasks completed successfully." || return 1
}

ENABLE_SUPERSET_SERVICE () {

echo "INFO: Creating a service file for superset"
cat << _EOL > ${PROJECT_DIR}/interface/superset.service
[Unit]
Description=Superset
After=network.target

[Service]
User=root
Group=root
WorkingDirectory=${PROJECT_DIR}/interface
EnvironmentFile=${PROJECT_DIR}/interface/.env
ExecStart=/bin/bash -c 'source ${PROJECT_DIR}/safesquid_reporting/bin/activate && /bin/bash ${PROJECT_DIR}/interface/run.sh -d'
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
_EOL

  ln -sf ${PROJECT_DIR}/interface/superset.service /etc/systemd/system/
  [ -f "/etc/systemd/system/superset.service" ] && systemctl daemon-reload
  systemctl enable superset.service && systemctl start superset.service
}

INFO () {
  echo ""
  echo "INFO: To activate your virtual enviornment execute below command."
  echo "source ${PROJECT_DIR}/safesquid_reporting/bin/activate"
  echo ""
  echo "You'll be requried to activate your virtual enviornment while importing data into your database manually"
}

MAIN () {

  SYS_PACKAGES
  PY_VERSION_CHECK
  #If python version is less than 3.10 then upgrade
  [[ ${PY_V_MAJOR}.${PY_V_MINOR} != 3.10 ]] && GET_PYTHON_3_10
  PY_VERSION_CHECK
  [[ ${PY_V_MAJOR}.${PY_V_MINOR} != 3.10 ]] && echo "INFO: python version not supported, 3.10 is required" && return 1
  CREATE_PY_ENV
  PY_PACKAGES
  SETUP_DIR
  CREATE_SUPERSET_CONFIG_PY
  CREATE_FLASK_ENV
  SETUP_PSQL
  CREATE_PSQL_CONF
  SETUP_SUPERSET
  ENABLE_SUPERSET_SERVICE
  INFO
}

MAIN