#!/bin/bash

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
# if [ -f .env ]; then
#   export $(cat .env | grep -v '^#' | xargs)
# else
#   echo ".env file not found. Please create one and try again."
#   exit 1
# fi

# Check if the necessary environment variables are set
if [ -z "$FLASK_APP" ] &&  [ -z "$SUPERSET_CONFIG_PATH" ]; then
  echo "Required environment variables FLASK_APP or SUPERSET_CONFIG_PATH are not set."
  exit 1
fi

# Run Apache Superset
COMMAND="superset run -p $PORT --with-threads"
if [ "$DEBUG" = true ]; then
  COMMAND="$COMMAND --reload --debugger"
fi

echo "Starting Apache Superset with command: $COMMAND"
$COMMAND

# Provide feedback on the status
if [ $? -eq 0 ]; then
  echo "Apache Superset started successfully."
else
  echo "Failed to start Apache Superset."
fi