import json
import pandas as pd
import csv
import sys

def convert_to_tsv(input_file, output_file):
    data_rows = []
    header = [
        '\"document-uri\"',
        '\"violated-directive\"',
        '\"effective-directive',
        '\"original-policy\"',
        '\"blocked-uri\"',
        '\"line-number\"',
        '\"source-file\"',
        '\"status-code\"',
        '\"user\"',
        '\"date\"',
        '\"CLIENTID\"',
        '\"USERNAME\"',
        '\"handler\"'
    ]

    with open(input_file, 'r') as file:
        # Skip the first line
        next(file)

        for line in file:
            try:
                # Parse the JSON data
                entry = json.loads(line.strip())
                csp_report = entry.get('csp-report', {})
                from_info = entry.get('from', {})
                info = entry.get('info', {})

                # Create a row of data with quotes around values
                data_row = {
                    '\"document-uri\"': f'"{csp_report.get("document-uri", "")}"',
                    '\"violated-directive\"': f'"{csp_report.get("violated-directive", "")}"',
                    '\"effective-directive\"': f'"{csp_report.get("effective-directive", "")}"',
                    '\"original-policy\"': f'"{csp_report.get("original-policy", "")}"',
                    '\"blocked-uri\"': f'"{csp_report.get("blocked-uri", "")}"',
                    '\"line-number\"': f'"{csp_report.get("line-number", "")}"',
                    '\"source-file': f'"{csp_report.get("source-file", "")}"',
                    '\"status-code': f'"{csp_report.get("status-code", "")}"',
                    '\"user': f'"{from_info.get("user", "")}"',
                    '\"date\"': f'"{from_info.get("date", "")}"',
                    '\"CLIENTID\"': f'"{info.get("CLIENTID", "")}"',
                    '\"USERNAME\"': f'"{info.get("USERNAME", "")}"',
                    '\"handler\"': f'"{info.get("handler", "")}"'
                }

                data_rows.append(data_row)
            except json.JSONDecodeError as e:
                print(f"Error parsing JSON: {e}")

    # Create a DataFrame and save as TSV
    df = pd.DataFrame(data_rows, columns=header)
    df.to_csv(output_file, sep='\t', index=False, quoting=csv.QUOTE_NONE, escapechar='\\')


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python script.py <input_file> <output_file>")
        sys.exit(1)

    input_file = sys.argv[1]  # First command line argument
    output_file = sys.argv[2]  # Second command line argument
    
    convert_to_tsv(input_file, output_file)
