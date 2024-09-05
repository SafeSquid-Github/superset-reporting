
# Getting Started with SuperSet

This guide will walk you through the setup and execution process for configuring SuperSet with SafeSquid Reporting. The `setup.sh` script will automate the configuration of various components necessary for the setup.

## Default Setup

### 1. Execute with Default Values

To start the setup process with the default configuration, execute the following command:

```bash
sudo bash setup.sh
```

### 2. Check Service Status

After the setup completes, verify that the services are running correctly:

```bash
systemctl status superset.service
systemctl status superset_db_insert_ext.service
systemctl status superset_db_insert_perf.service
systemctl status superset_db_insert_csp.service
```

Once the services are working without any issues, you can configure your client to forward logs to the log server (which in this case, will be your proxy server). 
To update the log settings, refer to the following documents:

- [Forwarding Logs to the aggregator Server](https://help.safesquid.com/portal/en/kb/articles/forwarding-logs-to-the-siem-server-by-configuring-the-udp-port)
- [SafeSquid Startup Parameters Overview](https://help.safesquid.com/portal/en/kb/articles/safesquid-startup-parameters#Overview)

**Note:** Using the startup parameters you can forward extended logs, however, for performance and CSP logs you are required to follow the method below for setting up the log forward.

### Setting Up rsyslog for Forwarding Performance and CSP Logs (For your proxy server)

To forward performance and CSP logs, you need to configure `rsyslog` using a custom configuration file. Follow the steps below:

1. **Download and Configure the rsyslog File**  
   Use the following command to download the custom `rsyslog.conf` file and place it in the correct directory:

   ```bash
   wget https://raw.githubusercontent.com/SafeSquid-Github/superset-reporting/master/proxy_rsyslog/proxyserver.conf -O /etc/rsyslog.d/proxyserver.conf
   ```

2. **Validate the Configuration**  
   Validate the configuration by running the following command:

   ```bash
   rsyslogd -N1 -f /etc/rsyslog.d/proxyserver.conf &> /dev/null && echo 'INFO: Config OK!!'
   ```

   If the configuration is correct, you will see the message: `INFO: Config OK!!`

3. **Restart the rsyslog Service**  
   After configuring, restart the `rsyslog` service to apply the changes:

   ```bash
   systemctl restart rsyslog.service
   ```

By following these steps, you will successfully set up `rsyslog` to forward performance and CSP logs.


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

## Process Flow
```
                               +----------------+
                               |  Proxy Server  |
                               +----------------+
                                      |
                                      | Pushes Logs
                                      v
                          +--------------------------+
                          |      rsyslog Server      |
                          | (Listening on UDP Ports) |
                          +--------------------------+
                           /             |             \
                          /              |              \
                         v               v               v
          +-------------------+  +-------------------+  +-------------------+
          |   Port 514 (Ext)   |  | Port 515 (Perf)   |  |   Port 516 (CSP)  |
          +-------------------+  +-------------------+  +-------------------+
                  |                     |                                |
                  |                     |                                |
                  v                     v                                v
 +--------------------------------+ +--------------------------------+ +--------------------------------+
 | /var/log/aggregator/rsyslog/   | | /var/log/aggregator/rsyslog/   | | /var/log/aggregator/rsyslog/   |
 | extended/%FROMHOST-IP%/        | | performance/%FROMHOST-IP%/     | | csp/%FROMHOST-IP%/             |
 | extended.log                   | | performance.log                | | csp.log                        |
 +--------------------------------+ +--------------------------------+ +--------------------------------+
                  |                           |                                 |
                  |                           |                                 |
                  v                           v                                 v
 +---------------------------------------------------------------------------------+
 |                                 Log Rotation                                    |
 |                            (Triggered at 100MB)                                 |
 +---------------------------------------------------------------------------------+
                       |                          |                     |
                       |                          |                     |
                       v                          v                     v
 +--------------------------------+ +--------------------------------+ +--------------------------------+
 | Insert into Extended DB        | | Insert into Performance DB     | | Insert into CSP DB             |
 +--------------------------------+ +--------------------------------+ +--------------------------------+
                  |                     |                     |
                  |                     |                     |
                  v                     v                     v
          +---------------------------------------------------------------------+
          |                            Database Services                        |
          +---------------------------------------------------------------------+
```