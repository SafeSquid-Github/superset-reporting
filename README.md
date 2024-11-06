# Getting Started with SuperSet

This guide will walk you through the setup and execution process for configuring SuperSet with SafeSquid Reporting. The `setup.sh` script will automate the configuration of various components necessary for the setup.

## Default Setup
> **Note**: Ensure you are logged in as the root user before performing any of the following actions. Root access is required for configuring services, modifying system files, and setting up log synchronization.

This guide will walk you through the setup and execution process for configuring SuperSet with SafeSquid Reporting. The `setup.sh` script will automate the configuration of various components necessary for the setup, including setting up Monit for log synchronization and monitoring.

### 1. Execute with Default Values

To start the setup process with the default configuration, execute the following command:

```bash
bash setup.sh
```

### 2. Check Service Status

After the setup completes, verify that the services are running correctly:

```bash
systemctl status superset.service
```

Once the services are running without any issues, you can configure your log server to pull logs from your proxy server.

## Setting Up rsync for Log Synchronization

To enable the aggregator to sync log files, follow these steps:

1. **Add SSH Key to SafeSquid Proxy Server**

   The SSH key for the log aggregator server can be found in `/opt/aggregator/setup_authorized_keys` on the log server. 
   Add this key to the `/root/.ssh/authorized_keys` file on each SafeSquid proxy server to allow secure access.

2. **Download and Set Up rrsync Script**

   Use `curl` to download the `rrsync` script to the SafeSquid proxy server:

   ```bash
   curl -o /usr/local/bin/rrsync https://raw.githubusercontent.com/SafeSquid-Github/superset-reporting/refs/heads/master/scripts/rrsync
   ```

   This will save the script to `/usr/local/bin/rrsync`.

3. **Set Execute Permissions**

   Ensure that `rrsync` has the appropriate permissions by running:

   ```bash
   chmod 755 /usr/local/bin/rrsync
   ```
4. **Specify Proxy Server IPs**

   After adding the authorization key, you must specify the IP addresses of the proxy servers from which the logs will be pulled. Open the file `/opt/aggregator/servers.list` on the log server and enter each proxy server’s IP address on a new line.

   For example:
   ```plaintext
   192.168.1.10
   192.168.1.11
   192.168.1.12
   ```

   This file will allow aggregator to pull logs from each specified proxy server.

## Monit Configuration

The `setup.sh` script automatically configures Monit to monitor and maintain the log synchronization process. Here’s what Monit will do:

1. **Log File Monitoring**:
   Monit checks the `/var/log/sync.log` file to ensure logs are synced:
   
   - If `sync.log` does not exist, Monit will create it.
   - If `sync.log` is older than an hour, Monit will trigger `sync.sh` to update logs and `insert.sh` to insert data into the databases.

2. **Server List Monitoring**:
   Monit also monitors the `/opt/aggregator/servers.list` file:
   
   - If `servers.list` is modified (e.g., a new IP is added), Monit will execute `sync.sh` to pull updated logs.

This Monit setup helps ensure your logs stay up-to-date, providing accurate data for SuperSet reports without manual intervention.

---
With these steps complete, your log server is now configured to securely pull logs from the SafeSquid proxy servers, to generate up-to-date reports.



## Manual Insertion of Logs into the Database

### 1. Activate Virtual Environment

Once the setup script has completed, activate the virtual environment to ensure all Python dependencies are correctly managed:

```
source /opt/aggregator/safesquid_reporting/bin/activate
```

### 2. Change to the Aggregator Directory

Navigate to the aggregator directory where the scripts are located:

```
cd /opt/aggregator/bin/
```

## Usage

The `main.py` script provides a command-line interface for managing the database and logs. Below are the available commands:

### 3. Create the Database

Next, you'll need to create the necessary databases for storing logs. The following commands will create databases based on the log type: extended or performance.

**Note:** The `create-database` command requires an argument specifying the log type (`extended` or `performance`). If you do not provide this argument, you will receive an error:

```
Usage: main.py create-database [OPTIONS] {extended|performance}
Try 'main.py create-database --help' for help.

Error: Missing argument '{extended|performance}'. Choose from:
        extended,
        performance
```

To create the database for extended logs:

**Example:**

```
python3 main.py create-database extended
```

To create the database for performance logs:

**Example:**

```
python3 main.py create-database performance
```

### 4. Insert Logs into the Database

To insert logs into the database at any time, use the following command. Ensure you're in the `aggregator` directory before executing:

Replace `<log_type>` with `extended` or `performance`, and `<log_file_path>` with the path to your log file.

**Note:** The `insert` command requires two arguments: the log type and the path to the log file. If either argument is missing, the command will fail with an error.

```
python main.py insert <log_type> <log_file_path>
```

**Example:**

```
python main.py insert extended /var/log/aggregator/rsyslog/extended/192.168.2.10/20240603164101-extended.log
```

# Custom Setup Options (For customizing the installation of SuperSet)

If you need to customize the setup (e.g., changing default user credentials, host, or database name), you can use the following steps.

### 1. Check the Help Menu

First, review the help menu to understand the available options:

```
bash setup.sh -h
```

### 2. Execute with Custom Values

To execute the setup with custom values, use the following command. Replace the placeholders with your desired values:

```
bash setup.sh -u admin -p password -H 127.0.0.1 -P 5432 -d safesquid_logs -a admin -w password -f admin -l admin -e admin@mail.com -D /opt/aggregator -v safesquid_reporting
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
- **-D DIRECTORY_NAME**: Directory name for the project (default: `/opt/aggregator`)
- **-v VENV_NAME**: Virtual environment path (default: `safesquid_reporting`)

## Additional Options in main.py

The `main.py` script offers several commands to manage and interact with your database. Below are some of the additional options available:

### Help Menu

For further assistance and details on each command:

```
python3 main.py --help
```

### Clear the Database

To clear the database and drop all tables:

```
python3 main.py clear-database
```

### Analyze the Database

To analyze the logs stored in the database and retrieve information about the database schema and row counts, use:

```
python3 main.py analyse-database
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
