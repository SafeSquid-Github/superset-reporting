#!/bin/bash

ENV="../etc/superset/.env"

# Function to print the usage of the script
usage() {
  echo "Usage: $0 [-p PORT] [-d]"
  echo "  -p PORT      Specify the port for Superset (default: 8088)"
  echo "  -d           Enable debug mode"
  exit 1
}

# Default values
PORT=8088
DEBUG=false

# Parse command line arguments
while getopts "p:dt:" opt; do
  case $opt in
    p)
      PORT=$OPTARG
      ;;
    d)
      DEBUG=true
      ;;
    *)
      usage
      ;;
  esac
done

# Load environment variables from the .env file
[ -f ${ENV} ] && export $(cat ${ENV} | grep -v '^#' | xargs)
[ ! -f ${ENV} ] && echo "${ENV} file not found. Please create one and try again." && exit 1

# Check if the necessary environment variables are set
[ -z "$FLASK_APP" ] &&  [ -z "$SUPERSET_CONFIG_PATH" ] && echo "Required environment variables FLASK_APP or SUPERSET_CONFIG_PATH are not set." && exit 1

# Run Apache Superset
COMMAND="superset run -p $PORT --with-threads"
[ "$DEBUG" = true ] && COMMAND="$COMMAND --reload --debugger"

echo "Starting Apache Superset with command: $COMMAND"
$COMMAND

# Provide feedback on the status
[ $? == 0 ] && echo "Apache Superset started successfully."
[ $? != 0 ] && echo "Failed to start Apache Superset."