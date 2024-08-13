import logging
from typing import List, Tuple
from concurrent.futures import ThreadPoolExecutor, as_completed
from tqdm import tqdm
import csv
from io import StringIO
from abc import ABC, abstractmethod
import xml.etree.ElementTree as ET
import gzip

from database import DatabaseConnectionPool, TableColumn

import applog

class LogColumn:
    """
        Represents a column in the log table with name, datatype, and constraints. 
    """
    def __init__(self, name: str, datatype: str, isArray:bool = False, isPrimary:bool = False, data_format:str = None, *args, **kwargs):
        self.name = name
        self.datatype = datatype
        self.isArray = isArray
        self.isPrimary = isPrimary
        self.data_format = data_format

    def __repr__(self) -> str:
        return f"{self.name} {self.datatype}{'[]' if self.isArray else ''}{f' {self.data_format}' if self.data_format else ''}{' PRIMARY KEY' if self.isPrimary else ''}"


class LogParser:
    def __init__(self, database: DatabaseConnectionPool, ftype="tsv",*args, **kwargs):
        self.database = database
        self.log_schema: List[LogColumn] = []
        self.file_type = ftype

    def create_tables(self) -> None:
        raise NotImplementedError("Method 'create_tables' must be implemented by a subclass.")

    def insert_log(self, log_data: Tuple) -> None:
        raise NotImplementedError("Method 'insert_log' must be implemented by a subclass.")
    
    def load_log_schema(self, log_type: str, xml_file: str) -> None:
        # Parse the XML file
        tree = ET.parse(xml_file)
        root = tree.getroot()
        
        # Find the specified log type
        log_schema = root.find(log_type)
        
        if log_schema is None:
            raise ValueError(f"Log type '{log_type}' not found in XML schema.")
        
        # Retrieve the type attribute from the log type element
        self.file_type = log_schema.get('type')
        
        # Convert the schema to a list of LogColumn objects
        for column in log_schema.findall('column'):
            name = column.get('name')
            datatype = column.get('datatype')
            isArray = column.get('array') == 'true'
            isPrimary = column.get('primaryKey') == 'true'
            data_format = column.get('format')
            
            self.log_schema.append(LogColumn(name, datatype, isArray, isPrimary, data_format))

    def insert_log_file(self, file_path: str, max_workers: int = 10) -> None:
        if file_path.endswith('.gz'):
            open_func = gzip.open
            mode = 'rt'  # Read text mode for gzip
        else:
            open_func = open
            mode = 'r'

        with open_func(file_path, mode) as file:
            lines = file.readlines()
        
        # Skip the header line
        lines = lines[1:]
        
        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            with tqdm(total=len(lines), desc="Inserting log lines") as pbar:
                futures = {executor.submit(self.insert_log, line.strip()): line.strip() for line in lines if line.strip()}
                for future in as_completed(futures):
                    try:
                        future.result()
                    except Exception as e:
                        line = futures[future]
                        applog.logger.warning(f"An error occurred while inserting the log line {line}: {e}")
                    finally:
                        pbar.update(1)
    
    def insert_log_files(self, log_files: List[str], workers:int = 10) -> None:
        for log_file in log_files:
            self.insert_log_file(log_file, workers)
            applog.logger.debug(f"Log file {log_file} inserted successfully.")

    def parse_log_line(self, log_line: str) -> Tuple:
        try:
            f = StringIO(log_line)

            if self.file_type == "tsv":
                reader = csv.reader(f, delimiter='\t')
                fields = next(reader)

                # Use list comprehension to process fields
                processed_fields = [
                    field.split(',') if ',' in field else field for field in fields
                ]
            elif self.file_type == "csv":
                reader = csv.reader(f)
                fields = next(reader)
                processed_fields = fields
            else:
                raise ValueError(f"Log file type '{type}' not supported.")
        except Exception as e:
            applog.logger.warning(f"Error parsing file: {e}")
            return None
        return tuple(processed_fields)

    def __repr__(self) -> str:
        str_logparser = f"Database: {self.database}\n"
        str_logparser += f"Log Schema:\n"
        for column in self.log_schema:
            str_logparser += f"{column}\n"
        str_logparser += f"File Type: {self.file_type}"
        return str_logparser
            
class BasicLogParser(LogParser):

    def __init__(self, database: DatabaseConnectionPool, main_table:str, *args, **kwargs):
        super().__init__(database, *args, **kwargs)
        self.main_table = main_table
        self.table_schema: List[TableColumn] = []

    def load_log_schema(self, log_type: str, xml_file: str) -> None:
        super().load_log_schema(log_type, xml_file)
        self.set_table_schema()
        for col in self.table_schema:
            applog.logger.debug(col)

    def set_table_schema(self) -> None:
        self.table_schema = [TableColumn(column.name, column.datatype, column.isArray, column.isPrimary, column.data_format) for column in self.log_schema]
    
    def create_tables(self) -> None:
        self.database.create_table(self.main_table, self.table_schema)

    def insert_log(self, log_line: str) -> None:
        # Parse the TSV string
        try:
            log_data = self.parse_log_line(log_line)
        except Exception as e:
            applog.logger.warning(f"Error parsing TSV: {e}")
            return None
        try:
            # Insert log entry
            self.database.insert_data(self.main_table, self.table_schema, log_data)
        except Exception as e:
            applog.logger.warning(f"Error inserting log: {e}")

    def __repr__(self) -> str:
        str_basiclogparser = super().__repr__()
        str_basiclogparser += f"\nMain Table: {self.main_table}"
        str_basiclogparser += "\nTable Schema:\n"
        for column in self.table_schema:
            str_basiclogparser += f"{column}\n"
        return str_basiclogparser