# Getting Started with SuperSet

This guide will walk you through the setup and execution process for configuring SuperSet with SafeSquid Reporting. 
The `setup.sh` script will configure the following for you:

- **Python 3.10**: The script ensures that Python 3.10 is installed on your system.
- **Virtual Environment**: A virtual environment will be set up to isolate the Python environment for SafeSquid Reporting.
- **SuperSet**: This setup assumes SuperSet is installed and configured on your system.

## Setup Steps

### 1. Execute with Default Values

To start the setup process with the default configuration, simply execute the following command:

```bash
bash setup.sh
```

### 2. Activate Virtual Environment

Once the setup script has completed, activate the virtual environment to ensure all Python dependencies are correctly managed:

```bash
source /opt/aggregator/superset/safesquid_reporting/bin/activate
```

### 3. Change to the Aggregator Directory

Navigate to the aggregator directory where the scripts are located:

```bash
cd /opt/aggregator/superset/aggregator/
```

## Usage

The `main.py` script provides a command-line interface for managing the database and logs. Below are the available commands:

### 4. Create the Database

Next, you'll need to create the necessary databases for storing logs. 
The following commands will create databases based on the log type: extended or performance.

**Note:** The `create-database` command requires an argument specifying the log type (`extended` or `performance`). 
If you do not provide this argument, you will receive an error:

```
Usage: main.py create-database [OPTIONS] {extended|performance}
Try 'main.py create-database --help' for help.

Error: Missing argument '{extended|performance}'. Choose from:
        extended,
        performance
```
To create the database for extended logs:
**Example:**
```bash
python main.py create-database extended
```

To create the database for performance logs:
**Example:**
```bash
python main.py create-database performance
```

### 5. Insert Logs into the Database

To insert logs into the database at any time, use the following command. Ensure you're in the `aggregator` directory before executing:

Replace `<log_type>` with `extended` or `performance`, and `<log_file_path>` with the path to your log file.

**Note:** The `insert` command requires two arguments: the log type and the path to the log file. If either argument is missing, the command will fail with an error.

```bash
python main.py insert <log_type> <log_file_path>
```
**Example:**
```bash
python main.py insert extended /var/log/safesquid/extended/20240603164101-extended.log
```

# Custom Setup Options (For customizing the installation of superset)

If you need to customize the setup (e.g., changing default user credentials, host, or database name), you can use the following steps.

### 1. Check the Help Menu

First, review the help menu to understand the available options:

```bash
bash setup.sh -h
```

### 2. Execute with Custom Values

To execute the setup with custom values, use the following command. Replace the placeholders with your desired values:

```bash
bash setup.sh -u admin -p password -H 127.0.0.1 -P 5432 -d safesquid_logs -a admin -w password -f admin -l admin -e admin@mail.com -D /opt/aggregator/superset -v /opt/aggregator/superset/safesquid_reporting
```

### 3. Explanation of Parameters

- **-u PGUSER**: PostgreSQL username (default: `admin`)
- **-p PGPASSWORD**: PostgreSQL password (default: `safesquid`)
- **-H PGHOST**: PostgreSQL host (default: `127.0.0.1`)
- **-P PGPORT**: PostgreSQL port (default: `5432`)
- **-d PGDATABASE**: PostgreSQL database name (default: `safesquid_logs`)
- **-a ADMIN_USERNAME**: Admin username for SuperSet (default: `admin`)
- **-w ADMIN_PASSWORD**: Admin password for SuperSet (default: `safesquid`)
- **-f ADMIN_FIRST_NAME**: Admin first name (default: `admin`)
- **-l ADMIN_LAST_NAME**: Admin last name (default: `admin`)
- **-e ADMIN_EMAIL**: Admin email address (default: `admin@mail.com`)
- **-D DIRECTORY_NAME**: Directory name for the project (default: `/opt/aggregator/superset`)
- **-v VENV_NAME**: Virtual environment path (default: `${PROJECT_DIR}/safesquid_reporting`)

## Additional Options in main.py

The main.py script offers several commands to manage and interact with your database. 
Below are some of the additional options available:

### Help Menu

For further assistance and details on each command:

```bash
python main.py --help
```

### Clear the Database

To clear the database and drop all tables:
Drops all the columns of extended and performance table.

```bash
python main.py clear-database
```

### Analyze the Database

To analyze the logs stored in the database and retrieve information about the database schema and row counts, use:

```bash
python main.py analyse-database
```

For example, analyzing the `extended_logs` table may produce output similar to this:

- **Table**: `extended_logs`
  - **Column**: `record_id`, Type: `text`
  - **Column**: `client_id`, Type: `integer`
  - **Column**: `request_id`, Type: `integer`
  - **Column**: `date_time`, Type: `timestamp without time zone`
  - **Column**: `elapsed_time`, Type: `integer`
  - **Column**: `status`, Type: `integer`
  - **Column**: `size`, Type: `integer`
  - **Column**: `upload`, Type: `integer`
  - **Column**: `download`, Type: `integer`
  - **Column**: `bypassed`, Type: `boolean`
  - **Column**: `client_ip`, Type: `text`
  - **Column**: `username`, Type: `text`
  - **Column**: `method`, Type: `text`
  - **Column**: `url`, Type: `text`
  - **Column**: `http_referer`, Type: `text`
  - **Column**: `useragent`, Type: `text`
  - **Column**: `mime`, Type: `text`
  - **Column**: `filter_name`, Type: `text`
  - **Column**: `filtering_reason`, Type: `text`
  - **Column**: `interface`, Type: `text`
  - **Column**: `cachecode`, Type: `text`
  - **Column**: `peercode`, Type: `text`
  - **Column**: `peer`, Type: `text`
  - **Column**: `request_host`, Type: `text`
  - **Column**: `request_tld`, Type: `text`
  - **Column**: `referer_host`, Type: `text`
  - **Column**: `referer_tld`, Type: `text`
  - **Column**: `range`, Type: `text`
  - **Column**: `time_profiles`, Type: `ARRAY`
  - **Column**: `user_groups`, Type: `ARRAY`
  - **Column**: `request_profiles`, Type: `ARRAY`
  - **Column**: `application_signatures`, Type: `ARRAY`
  - **Column**: `categories`, Type: `ARRAY`
  - **Column**: `response_profiles`, Type: `ARRAY`
  - **Column**: `upload_content_types`, Type: `ARRAY`
  - **Column**: `download_content_types`, Type: `ARRAY`
  - **Column**: `profiles`, Type: `ARRAY`
  - **Row count**: `67225`