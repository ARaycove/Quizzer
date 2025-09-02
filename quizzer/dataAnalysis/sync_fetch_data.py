import json
import os
import supabase
import sqlite3
from sqlite3 import Connection
import datetime
import typing

SUPABASE_URL = "https://yruvxuvzztnahuuiqxit.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlydXZ4dXZ6enRuYWh1dWlxeGl0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQzMTY1NDIsImV4cCI6MjA1OTg5MjU0Mn0.hF1oAILlmzCvsJxFk9Bpjqjs3OEisVdoYVZoZMtTLpo"

DB_FILE = "data.db"
LAST_SYNC_FILE = "last_sync.json"
SUPABASE_TABLE = "question_answer_pairs"

def upsert_records_to_db(records: typing.List[typing.Dict], db: sqlite3.Connection) -> None:
    """
    Upserts a list of records into the local SQLite database.

    This function dynamically constructs the SQL query and data list
    based on the keys of the first record, making it more concise.

    Args:
        records: A list of dictionaries representing the records to be upserted.
        db: The SQLite database connection object.
    """
    print("\n--- Starting upsert_records_to_db ---")
    if not records:
        print("No records to upsert. Exiting.")
        return

    print(f"Received {len(records)} records for upsert.")
    cursor = db.cursor()

    # Explicitly define the column order to ensure correct mapping.
    # This list must match the schema of your SQLite table.
    columns = [
        "question_id", "time_stamp", "citation", "question_elements",
        "answer_elements", "concepts", "subjects", "module_name",
        "question_type", "options", "correct_option_index",
        "correct_order", "index_options_that_apply", "qst_contrib",
        "ans_contrib", "qst_reviewer", "has_been_reviewed",
        "ans_flagged", "flag_for_removal", "completed",
        "last_modified_timestamp", "has_media", "answers_to_blanks"
    ]
    
    column_names = ', '.join(columns)
    placeholders = ', '.join('?' * len(columns))

    # Dynamically build the SQL statement
    upsert_sql = f"REPLACE INTO question_answer_pairs ({column_names}) VALUES ({placeholders})"
    print(f"Generated SQL: {upsert_sql}")

    # Create a list of tuples from the dictionaries for bulk upserting.
    data_to_upsert = [
        tuple(record.get(col) for col in columns) for record in records
    ]

    print(f"Data to upsert (first record): {data_to_upsert[0]}")

    try:
        cursor.executemany(upsert_sql, data_to_upsert)
        print("executemany command executed.")
        db.commit()
        print(f"Successfully committed {len(records)} records to the database.")
    except sqlite3.Error as e:
        print(f"SQLite error during upsert: {e}")
    finally:
        print("--- upsert_records_to_db finished ---")


def find_newest_timestamp(records: typing.List[typing.Dict]) -> typing.Union[str, None]:
    """
    Finds the newest 'last_modified_timestamp' in a list of record dictionaries.

    Args:
        records: A list of dictionaries, where each dictionary represents a record
                 and is expected to have a 'last_modified_timestamp' key.

    Returns:
        The string value of the newest timestamp, or None if the list is empty.
    """
    if not records:
        return None

    newest_record = max(records, key=lambda x: x.get('last_modified_timestamp', ''))
    return newest_record.get('last_modified_timestamp')

def fetch_new_records_from_supabase(supabase_client: supabase.Client, last_sync_date: str) -> list:
    """
    Fetches all new records from the Supabase table since the last sync date.

    This function uses a timestamp filter and pagination to retrieve all records
    that have been created or modified after the provided `last_sync_date`.

    Args:
        supabase_client: The initialized Supabase client object.
        last_sync_date: The timestamp string to filter records by. Records newer
                        than this timestamp will be returned.

    Returns:
        A list of dictionaries, where each dictionary represents a row from the
        Supabase table.
    """
    all_records = []
    page_limit = 500
    offset = 0

    while True:
        # Query the database for records with a newer timestamp
        # Paginate by `page_limit` and `offset`
        response = (
            supabase_client.table(SUPABASE_TABLE)
            .select('*')
            .gt('last_modified_timestamp', last_sync_date)
            .order('last_modified_timestamp')
            .range(offset, offset + page_limit - 1)
            .execute()
        )

        page_data = response.data
        
        # If the page is empty, we've reached the end of the data
        if not page_data:
            break
        
        # Add the fetched records to the list
        all_records.extend(page_data)
        
        # If the number of records on the page is less than the page limit, it's the last page
        if len(page_data) < page_limit:
            break
        
        # Move to the next page
        offset += page_limit

    return all_records

def get_last_sync_date():
    last_sync_date = "1970-01-01T00:00:00+00:00"
    if os.path.exists(LAST_SYNC_FILE):
        with open(LAST_SYNC_FILE, "r") as f:
            data = json.load(f)
            last_sync_date = data.get("last_sync_date", last_sync_date)
    return last_sync_date

def update_last_sync_date(new_date: typing.Union[str, None]) -> None:
    """
    Saves a given timestamp string to 'last_sync.json'.

    The function checks if the provided date is a valid string. If it is None,
    the function will exit without saving to avoid overwriting the last sync
    date with a null value.

    Args:
        new_date: A string representing the timestamp to save, or None.
    """
    if new_date is None:
        return

    data = {"last_sync_date": new_date}
    print(f"New last sync time: {new_date}")
    with open("last_sync.json", "w") as f:
        json.dump(data, f)

def initialize_supabase_session():
    '''Returns a SyncClient supabase client session object'''
    if SUPABASE_URL == "YOUR_SUPABASE_URL" or SUPABASE_KEY == "YOUR_SUPABASE_KEY":
        print("Error: Supabase credentials are not configured. Please update SUPABASE_URL and SUPABASE_KEY.")
        return
    try:
        supabase_client = supabase.create_client(SUPABASE_URL, SUPABASE_KEY)
    except Exception as e:
        print(f"Error connecting to Supabase: {e}")
        return
    
    return supabase_client

def initialize_and_fetch_db() -> Connection:
    db: Connection = sqlite3.connect(DB_FILE)

    create_sql_table_if_not_exists(db)

    return db

def create_sql_table_if_not_exists(db) -> None:
    create_table_sql = """
    CREATE TABLE IF NOT EXISTS question_answer_pairs (
        question_id TEXT NOT NULL PRIMARY KEY,
        time_stamp TEXT,
        citation TEXT,
        question_elements TEXT NOT NULL,
        answer_elements TEXT NOT NULL,
        concepts TEXT,
        subjects TEXT,
        module_name TEXT NOT NULL,
        question_type TEXT NOT NULL,
        options TEXT,
        correct_option_index INTEGER,
        correct_order TEXT,
        index_options_that_apply TEXT,
        qst_contrib TEXT NOT NULL,
        ans_contrib TEXT,
        qst_reviewer TEXT,
        has_been_reviewed INTEGER NOT NULL DEFAULT 0,
        ans_flagged INTEGER NOT NULL DEFAULT 0,
        flag_for_removal INTEGER NOT NULL DEFAULT 0,
        completed INTEGER,
        last_modified_timestamp TEXT,
        has_media SMALLINT,
        answers_to_blanks TEXT
    );
    """
    db.cursor().execute(create_table_sql)

def fetch_and_save_data_locally() -> None:
    # First we need initialize our supabase client and the local db file:
    print("Now Initializing Supabase Client")
    supabase_client: supabase = initialize_supabase_session()
    print("Now Initializing database object")
    db: sqlite3 = initialize_and_fetch_db()

    # Get the last sync date
    last_sync_date: datetime = get_last_sync_date()
    print(f"Got last sync time of: {last_sync_date}")
    # Pass that into and then fetch the new question records to be analyzed
    new_records: list = fetch_new_records_from_supabase(
        supabase_client     =supabase_client,
        last_sync_date      =last_sync_date
    )
    print(f"Got {len(new_records)} total records from supabase")
    # Assuming we got anything back, update the last sync date for future runs
    update_last_sync_date(find_newest_timestamp(records=new_records))


    # Now we need to save the new records to our local db file:
    upsert_records_to_db(
        records=new_records, 
        db = db)
    
    print(f"Hello?")

def main():
    fetch_and_save_data_locally()


if __name__ == "__main__":
    main()