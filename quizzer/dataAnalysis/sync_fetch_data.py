import json
import os
import supabase
import sqlite3
from sqlite3 import Connection
import datetime
import numpy as np
import typing

SUPABASE_URL = "https://yruvxuvzztnahuuiqxit.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlydXZ4dXZ6enRuYWh1dWlxeGl0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQzMTY1NDIsImV4cCI6MjA1OTg5MjU0Mn0.hF1oAILlmzCvsJxFk9Bpjqjs3OEisVdoYVZoZMtTLpo"

DB_FILE = "data.db"
LAST_SYNC_FILE = "last_sync.json"
SUPABASE_TABLE = "question_answer_pairs"

def upsert_question_record(db: Connection, question_record) -> bool:
    """
    Upserts a question record to the database.
    Updates if question_id exists, inserts if it doesn't.
    Ensures required columns exist before attempting upsert.
    
    Args:
        db: SQLite database connection
        question_record: Dictionary containing question data with question_id
        
    Returns:
        True if successful, False otherwise
    """
    cursor = db.cursor()
    
    try:
        # Get question_id for the upsert
        question_id = question_record.get('question_id')
        if not question_id:
            print("Error: question_record must contain 'question_id'")
            return False
        
        # Convert numpy arrays to JSON strings for storage
        processed_record = {}
        for key, value in question_record.items():
            if isinstance(value, np.ndarray):
                processed_record[key] = json.dumps(value.tolist())
            elif isinstance(value, list):
                processed_record[key] = json.dumps(value)
            else:
                processed_record[key] = value
        
        # Get all columns from the table
        cursor.execute("PRAGMA table_info(question_answer_pairs)")
        table_columns = [column[1] for column in cursor.fetchall()]
        
        # Ensure required columns exist - add them if missing
        required_columns = {
            'question_vector': 'TEXT',
            'is_math': 'INTEGER',  # SQLite stores booleans as integers
            'keywords': 'TEXT'
        }
        
        for column_name, column_type in required_columns.items():
            if column_name not in table_columns:
                print(f"Adding missing column: {column_name}")
                cursor.execute(f"ALTER TABLE question_answer_pairs ADD COLUMN {column_name} {column_type}")
                table_columns.append(column_name)
        
        db.commit()
        
        # Check if record exists
        cursor.execute("SELECT question_id FROM question_answer_pairs WHERE question_id = ?", (question_id,))
        exists = cursor.fetchone() is not None
        
        if exists:
            # UPDATE existing record - only update the fields we want to change
            update_fields = ['question_vector', 'is_math', 'keywords']
            update_values = []
            set_clauses = []
            
            for field in update_fields:
                if field in processed_record:
                    set_clauses.append(f"{field} = ?")
                    update_values.append(processed_record[field])
            
            if set_clauses:
                update_values.append(question_id)  # For WHERE clause
                query = f"UPDATE question_answer_pairs SET {', '.join(set_clauses)} WHERE question_id = ?"
                cursor.execute(query, update_values)
            
        else:
            # INSERT new record - filter to only existing columns
            filtered_record = {k: v for k, v in processed_record.items() if k in table_columns}
            
            if not filtered_record:
                print("Error: No valid columns found in question_record")
                return False
            
            columns = list(filtered_record.keys())
            placeholders = ['?' for _ in columns]
            values = list(filtered_record.values())
            
            query = f"INSERT INTO question_answer_pairs ({', '.join(columns)}) VALUES ({', '.join(placeholders)})"
            cursor.execute(query, values)
        
        db.commit()
        
        print(f"Successfully upserted record with question_id: {question_id}")
        return True
        
    except Exception as e:
        print(f"Error upserting question record: {e}")
        db.rollback()
        return False

def get_empty_vector_record(db: Connection):
    """
    Fetches one record from question_answer_pairs where question_vector is empty/null.
    Creates the question_vector column if it doesn't exist.
    
    Args:
        db: SQLite database connection
        
    Returns:
        Dictionary containing the record data, or None if no empty records found
    """
    cursor = db.cursor()
    
    # Check if question_vector column exists, create if not
    try:
        cursor.execute(f"PRAGMA table_info({SUPABASE_TABLE})")
        columns = [column[1] for column in cursor.fetchall()]
        
        if 'question_vector' not in columns:
            print("Creating question_vector column...")
            cursor.execute("ALTER TABLE question_answer_pairs ADD COLUMN question_vector TEXT")
            db.commit()
            print("question_vector column created successfully.")
    
    except Exception as e:
        print(f"Error checking/creating question_vector column: {e}")
        return None
    
    # Fetch one record where question_vector is null or empty
    try:
        cursor.execute("""
            SELECT * FROM question_answer_pairs 
            WHERE question_vector IS NULL OR question_vector = '' 
            LIMIT 1
        """)
        
        row = cursor.fetchone()
        if row is None:
            return None
            
        # Get column names
        column_names = [description[0] for description in cursor.description]
        
        # Convert row to dictionary
        record = dict(zip(column_names, row))
        return record
        
    except Exception as e:
        print(f"Error fetching empty vector record: {e}")
        return None

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

def sync_vectors_to_supabase():
    """
    Syncs question_vector data from local database to Supabase.
    Only updates records that are missing question_vector on Supabase.
    Continues until all records on Supabase have been updated or no more can be updated.
    """
    db = initialize_and_fetch_db()
    supabase_client = initialize_supabase_session()
    
    if not supabase_client:
        print("Error: Could not initialize Supabase session")
        return False
    
    # Authenticate with email and password
    try:
        auth_response = supabase_client.auth.sign_in_with_password({
            "email": "aacra0820@gmail.com",
            "password": "Starting11Over!"
        })
        print("Successfully authenticated with Supabase")
    except Exception as e:
        print(f"Error authenticating with Supabase: {e}")
        return False
    
    cursor = db.cursor()
    
    try:
        total_updated = 0
        batch_size = 100  # Process in batches to avoid overwhelming the server
        
        while True:
            # Query Supabase for records missing question_vector
            response = supabase_client.table('question_answer_pairs')\
                .select('question_id')\
                .is_('question_vector', 'null')\
                .limit(batch_size)\
                .execute()
            
            if not response.data:
                print(f"Sync complete. Total records updated: {total_updated}")
                break
            
            missing_question_ids = [record['question_id'] for record in response.data]
            print(f"Found {len(missing_question_ids)} records missing question_vector on Supabase")
            
            batch_updated = 0
            
            for question_id in missing_question_ids:
                # Get the question_vector from local database
                cursor.execute(
                    "SELECT question_vector FROM question_answer_pairs WHERE question_id = ?", 
                    (question_id,)
                )
                local_record = cursor.fetchone()
                
                if not local_record or not local_record[0]:
                    print(f"Warning: No question_vector found in local DB for question_id: {question_id}")
                    continue
                
                question_vector = local_record[0]
                
                # Update the record on Supabase
                try:
                    update_response = supabase_client.table('question_answer_pairs')\
                        .update({'question_vector': question_vector})\
                        .eq('question_id', question_id)\
                        .execute()
                    
                    if update_response.data:
                        batch_updated += 1
                        print(f"Updated question_vector for question_id: {question_id}")
                    else:
                        print(f"Warning: Failed to update question_id: {question_id}")
                        
                except Exception as e:
                    print(f"Error updating question_id {question_id}: {e}")
                    continue
            
            total_updated += batch_updated
            print(f"Batch complete. Updated {batch_updated} records in this batch.")
            
            # If no records were updated in this batch, break to avoid infinite loop
            if batch_updated == 0:
                print("No more records could be updated. Stopping sync.")
                break
        
        return True
        
    except Exception as e:
        print(f"Error during sync: {e}")
        return False
    
    finally:
        if db:
            db.close()

def main():
    fetch_and_save_data_locally()


if __name__ == "__main__":
    main()