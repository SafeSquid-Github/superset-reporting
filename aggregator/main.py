import os
import click
import configparser
from database import DatabaseConnectionPool as Database
from log_parser import LogParser, BasicLogParser
import applog

class AppContext:
    def __init__(self):
        self.db_manager: Database = None
        self.parser: LogParser = None

    def configure_logging(self, log_file:str):
        """Configure logging to log errors to console and exceptions/warnings to file."""
        applog.set_logger(__name__, log_file)
        applog.set_logger_level('DEBUG')
        applog.track_module('database')
        applog.track_module('log_parser')

    def load_parser(self, log_type: str):
        """Load the appropriate log parser based on log type."""
        self.parser = BasicLogParser(self.db_manager, f"{log_type}_logs")
        self.parser.load_log_schema(log_type, 'log_structure.xml')

pass_context = click.make_pass_decorator(AppContext, ensure=True)

@click.group()
@pass_context
def cli(ctx: AppContext):
    """Command-line interface for managing the database and logs."""
    config = configparser.ConfigParser()
    config.read('config.ini')
    username = config['database']['username']
    password = config['database']['password']
    host = config['database']['host']
    port = config['database']['port']  # Port remains as a string
    dbname = config['database']['dbname']
    maxconns = config['database']['maxconns']
    ctx.db_manager = Database(username, password, host, port, dbname, maxconns)

    ctx.configure_logging('app.log')

@cli.command()
@pass_context
def analyse_database(ctx: AppContext):
    """Analyze logs in the database."""
    print(ctx.db_manager)  # Placeholder for actual analysis logic

@cli.command()
@pass_context
def clear_database(ctx: AppContext):
    """Clear database and drop all tables."""
    ctx.db_manager.clear_database()

@cli.command()
@click.argument('log_type', type=click.Choice(['extended', 'performance'], case_sensitive=False), required=True)
@pass_context
def create_database(ctx: AppContext, log_type: str):
    """
    Create database and tables for log type.
    
    log_type: Type of log to create database for. Choices are 'extended' or 'performance'.
    """
    ctx.load_parser(log_type)
    ctx.parser.create_tables()

@cli.command()
@click.argument('log_type', type=click.Choice(['extended', 'performance'], case_sensitive=False), default='extended')
@click.argument('path', type=click.Path(exists=True))
@click.option('--workers', type=click.IntRange(1, 100), default=10, help='Number of workers to use for insertion.')
@pass_context
def insert(ctx: AppContext, log_type: str, path: str, workers: int):
    """
    Insert log entries from a file into the database.
    
    log_type: Type of log to insert. Choices are 'extended' or 'performance'.
    path: Path to the log file or directory containing log files.
    workers: Number of workers to use for insertion.
    """

    def check_format(path:str):
        if path.endswith('.log') or path.endswith('.log.gz'):
            return True
        else:
            return False

    # Check if path is a file or a directory
    log_files = []
    if os.path.isdir(path):
        for file in os.listdir(path):
            if check_format(file):
                log_file = os.path.join(path, file)
                log_files.append(log_file)
    elif check_format(path):
        log_files.append(path)
    else:
        print("Invalid log file format. Please provide a valid log file.")
        return

    ctx.load_parser(log_type)
    ctx.parser.insert_log_files(log_files, workers)
    print("Logs inserted successfully.")

if __name__ == "__main__":
    cli()