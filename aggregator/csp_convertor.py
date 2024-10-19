import json
import pandas as pd
import csv
import sys

def convert_to_tsv(input_file, output_file):
    data_rows = []
    header = [
        '\"document_uri\"',
        '\"referrer\"',
        '\"violated_directive\"',
        '\"effective_directive\"',
        '\"original_policy\"',
        '\"disposition\"',
        '\"blocked_uri\"',
        '\"status_code\"',
        '\"source_file\"',
        '\"line_number\"',
        '\"column_number\"',
        '\"script_sample\"',
        '\"from_user\"',
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
                    '\"document_uri\"': f'"{csp_report.get("document-uri", "-")}"',
                    '\"referrer\"': f'"{csp_report.get("referrer", "-")}"',
                    '\"violated_directive\"': f'"{csp_report.get("violated-directive", "-")}"',
                    '\"effective_directive\"': f'"{csp_report.get("effective-directive", "-")}"',
                    '\"original_policy\"': f'"{csp_report.get("original-policy", "-")}"',
                    '\"disposition\"': f'"{csp_report.get("disposition", "-")}"',
                    '\"blocked_uri\"': f'"{csp_report.get("blocked-uri", "-")}"',
                    '\"status_code\"': int(csp_report.get("status-code", 0)),
                    '\"source_file\"': f'"{csp_report.get("source-file", "-")}"',
                    '\"line_number\"': int(csp_report.get("line-number", 0)),
                    '\"column_number\"': int(csp_report.get("column-number", 0)),
                    '\"script_sample\"': f'"{csp_report.get("script-sample", "-")}"',
                    '\"from_user\"': f'"{from_info.get("user", "-")}"',
                    '\"date\"': int(from_info.get("date", 0)),
                    '\"CLIENTID\"': int(info.get("CLIENTID", 0)),
                    '\"USERNAME\"': f'"{info.get("USERNAME", "-")}"',
                    '\"handler\"': f'"{info.get("handler", "-")}"'
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
