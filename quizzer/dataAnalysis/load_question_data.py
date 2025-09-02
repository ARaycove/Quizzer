import pandas as pd
import json
import sqlite3
from sqlite3 import Connection
from sync_fetch_data import initialize_and_fetch_db

def load_question_data() -> pd.DataFrame:
    """
    Retrieves data from the local SQLite database and loads it into a Pandas DataFrame,
    with pre-processing to ensure correct data types.

    This function performs the following steps:
    1.  Calls `initialize_and_fetch_db` to get the database connection.
    2.  Reads all records from the 'question_answer_pairs' table into a DataFrame.
    3.  Applies a pre-processing function to each record to clean data types.
    4.  Closes the database connection.
    5.  Returns the resulting DataFrame.

    Returns:
        A pandas.DataFrame containing the data from the 'question_answer_pairs' table
        with cleaned data types.
    """
    db: Connection = initialize_and_fetch_db()
    
    query = "SELECT * FROM question_answer_pairs"
    
    df = pd.read_sql_query(query, db)
    
    db.close()
    
    # Apply the pre-processing function to each row of the DataFrame
    df = df.apply(lambda row: pre_process_record(row.to_dict()), axis=1)

    return df

def pre_process_record(record):
    """
    Pre-processes a single record dictionary to correct data types.

    This function specifically targets fields that are stored as strings but
    contain JSON or other structured data and converts them to the correct
    Python objects (e.g., list, dict). It also handles numeric conversions.

    Args:
        record: A dictionary representing a single record from the database.

    Returns:
        The updated dictionary with corrected data types.
    """
    # Define fields that should be parsed from JSON strings
    json_fields = [
        "question_elements",
        "answer_elements",
        "options",
        "index_options_that_apply"
        "answers_to_blanks"
    ]

    for field in json_fields:
        value = record.get(field)
        if isinstance(value, str):
            try:
                record[field] = json.loads(value)
            except json.JSONDecodeError:
                # If JSON parsing fails, the field remains a string.
                pass
    
    # Handle numeric fields that might be stored as floats with NaN
    # or need conversion to integers.
    numeric_fields = ["correct_option_index", "completed", "has_media", "has_been_reviewed", "ans_flagged", "flag_for_removal"]
    for field in numeric_fields:
        value = record.get(field)
        # Check if the value is not None and is not a pandas-specific NaN
        if pd.notna(value):
            try:
                record[field] = int(value)
            except (ValueError, TypeError):
                # In case of conversion error, the field remains unchanged.
                pass
        else:
            record[field] = None # Explicitly set NaN to None
            
    return record

def validate_first_record(df: pd.DataFrame) -> None:
    """
    Validates the first record of a DataFrame by printing its fields, values, and types.

    This function iterates through the columns of the first row of the provided
    DataFrame and provides a formatted output for each field. For complex data types
    like lists or dictionaries, it also inspects the types of their contents.

    Args:
        df: The pandas DataFrame to be validated.
    """
    if df.empty:
        print("DataFrame is empty. No records to validate.")
        return

    first_record = df.iloc[0]
    print("--- Validating First Record ---")
    
    for field_name, value in first_record.items():
        print(f"Field Name: {field_name}")
        print(f"Value: {value}")
        print(f"Type: {type(value).__name__}")
        
        # Check for complex types and inspect their contents
        if isinstance(value, list):
            if value:
                # Check the type of the first element in the list
                inner_type = type(value[0]).__name__
                print(f"  List contains elements of type: {inner_type}")
            else:
                print("  List is empty.")
        
        elif isinstance(value, dict):
            if value:
                # Check the type of the first key and value in the dictionary
                first_key, first_val = next(iter(value.items()))
                key_type = type(first_key).__name__
                val_type = type(first_val).__name__
                print(f"  Dictionary contains key type: {key_type}, value type: {val_type}")
            else:
                print("  Dictionary is empty.")
        
        print("-" * 20)

def main():
    validate_first_record(load_question_data())

if __name__ == "__main__":
    main()