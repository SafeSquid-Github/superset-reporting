import configparser
import logging
import time
from typing import List, Tuple, Dict, Union
import psycopg2
from psycopg2 import pool, extras
from psycopg2.extras import Json

import applog

class TableColumn:
    """
        Represents a column in the table with name, datatype, and constraints. 
    """
    def __init__(self, name: str, datatype: str, isArray:bool = False, isPrimary:bool = False, data_format: str = None, *args, **kwargs):
        self.name = name
        self.datatype = datatype
        self.isArray = isArray
        self.isPrimary = isPrimary
        self.data_format = data_format

    def __repr__(self) -> str:
        return f"{self.name} {self.datatype}{'[]' if self.isArray else ''}{' PRIMARY KEY' if self.isPrimary else ''}"

class DatabaseConnectionPool:
    def __init__(self, username: str, password: str, host: str, port: str, dbname: str, max_conns=1000):
        self.conn_str = f"postgres://{username}:{password}@{host}:{port}/{dbname}"
        self.pool = pool.SimpleConnectionPool(1, max_conns, self.conn_str)

    def get_connection(self, timeout=10) -> psycopg2.extensions.connection:
        """Attempt to retrieve a connection from the pool with a timeout."""
        for _ in range(timeout):
            try:
                conn = self.pool.getconn()
                if conn:
                    return conn
            except pool.PoolError:
                applog.logger.debug("Connection pool exhausted. Waiting to retry...")
                time.sleep(1)
        raise Exception("Failed to obtain connection within timeout period")

    def release_connection(self, conn: psycopg2.extensions.connection) -> None:
        self.pool.putconn(conn)

    def execute_command(self, sql_commands: str, values: Tuple = None) -> List[Tuple]:
        conn = self.get_connection()
        with conn.cursor() as cursor:
            try:
                cursor.execute('BEGIN;')
                # Convert Python lists to PostgreSQL arrays
                cursor.execute(sql_commands, values)
                result = cursor.fetchall() if cursor.description else []
            except Exception as e:
                conn.rollback()  # Rollback in case of error
                raise e
            else:
                conn.commit()  # Commit the transaction if all commands succeed
            finally:
                self.release_connection(conn)
        return result

    def close_connection(self) -> None:
        self.pool.closeall()
        applog.logger.debug("Database connection closed.")
    
    def __del__(self):
        self.close_connection()

    def fetch_table_schema(self) -> Dict[str, List[Tuple[str, str]]]:
        query = """
        SELECT table_name, column_name, data_type
        FROM information_schema.columns
        WHERE table_schema = 'public'
        ORDER BY table_name, ordinal_position;
        """
        schema: Dict[str, List[Tuple[str, str]]] = {}
        for table_name, column_name, data_type in self.execute_command(query):
                if (table_name not in schema):
                    schema[table_name] = []
                schema[table_name].append((column_name, data_type))
        return schema

    def fetch_table_row_counts(self) -> Dict[str, int]:
        query = """
        SELECT table_name, 
               (xpath('/row/c/text()', query_to_xml(format('SELECT COUNT(*) AS c FROM %s', table_name), false, true, '')))[1]::text::int AS row_count
        FROM information_schema.tables
        WHERE table_schema = 'public';
        """        
        row_counts: Dict[str, int] = {table_name: row_count for table_name, row_count in self.execute_command(query)}
        return row_counts

    def clear_database(self) -> None:
        table_names = self.fetch_table_names()
        for table_name in table_names:
            self.execute_command(f"DROP TABLE {table_name} CASCADE")
        applog.logger.debug("All tables dropped successfully.")

    def fetch_table_names(self) -> List[str]:
        query = """
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = 'public' AND table_type = 'BASE TABLE';
        """
        table_names = [row[0] for row in self.execute_command(query)]
        return table_names

    def create_table(self, table_name:str, schema: List[TableColumn]):
        """Creates a table with the given name and schema."""

        columns = ', '.join(str(col) for col in schema)
        query = f"CREATE TABLE {table_name} ({columns});"
        self.execute_command(query)
        applog.logger.debug(f"Table {table_name} created successfully.")
    
    def insert_data(self, table_name: str, columns: List[TableColumn], values: Tuple) -> None:
        assert len(columns) == len(values), f"Number of columns ({len(columns)}) and values ({len(values)}) do not match"
        
        columns_str = ', '.join([col.name for col in columns])
        placeholders = []
        formatted_values = []
        
        for col, val in zip(columns, values):
            if col.data_format:
                placeholders.append(f"to_timestamp(%s, '{col.data_format}')")
                formatted_values.append(val)
            else:
                placeholders.append('%s')
                formatted_values.append(val if not col.isArray else [val])
        
        placeholders_str = ', '.join(placeholders)
        query = f'INSERT INTO {table_name} ({columns_str}) VALUES ({placeholders_str}) ON CONFLICT DO NOTHING'
        self.execute_command(query, formatted_values)
    
    def __repr__(self) -> str:
        schema = self.fetch_table_schema()
        row_counts = self.fetch_table_row_counts()
        repr_str = "Database Schema and Row Counts:\n"
        for table, columns in schema.items():
            repr_str += f"Table: {table}\n"
            for column_name, data_type in columns:
                repr_str += f"  Column: {column_name}, Type: {data_type}\n"
            row_count = row_counts.get(table, 0)
            repr_str += f"  Row count: {row_count}\n\n"
        return repr_str