import json
import os
import supabase
import sqlite3
from sqlite3 import Connection
import datetime
import numpy as np
import typing
import random
import asyncio

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
            update_fields = ['question_vector', 'doc']
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

def get_empty_doc_record(db: Connection):
    """
    Fetches one record from question_answer_pairs where doc is empty/null.
    Creates the doc column if it doesn't exist.
    
    Args:
        db: SQLite database connection
        
    Returns:
        Dictionary containing the record data, or None if no empty records found
    """
    cursor = db.cursor()
    
    # Check if doc column exists, create if not
    try:
        cursor.execute(f"PRAGMA table_info({SUPABASE_TABLE})")
        columns = [column[1] for column in cursor.fetchall()]
        
        if 'doc' not in columns:
            print("Creating doc column...")
            cursor.execute("ALTER TABLE question_answer_pairs ADD COLUMN doc TEXT")
            db.commit()
            print("doc column created successfully.")
    
    except Exception as e:
        print(f"Error checking/creating doc column: {e}")
        return None
    
    # Fetch one record where doc is null or empty
    try:
        cursor.execute("""
            SELECT * FROM question_answer_pairs 
            WHERE doc IS NULL OR doc = '' 
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
        print(f"Error fetching empty doc record: {e}")
        return None


def upsert_records_to_db(records: typing.Union[typing.List[typing.Dict], typing.Dict[str, typing.List[typing.Dict]]], db: sqlite3.Connection, supabase_client) -> None:
    """
    Upserts records into the local SQLite database.
    This function handles both the old format (list of records for question_answer_pairs)
    and new format (dictionary with table names as keys).
    Automatically syncs schema with Supabase for question_answer_attempts and question_answer_pairs tables.
    Args:
        records: Either a list of records (legacy) or a dictionary with table names as keys.
        db: The SQLite database connection object.
        supabase_client: The Supabase client for schema synchronization.
    """
    print("\n--- Starting upsert_records_to_db ---")
    
    # Handle different input formats
    if isinstance(records, list):
        # Legacy format - assume question_answer_pairs
        records_dict = {'question_answer_pairs': records}
    elif isinstance(records, dict):
        # New format - dictionary with table names
        records_dict = records
    else:
        raise ValueError("Invalid records format. Must be list or dict.")
    
    if not records_dict:
        print("No records dictionary provided. Exiting.")
        return
    
    cursor = db.cursor()
    
    # Tables to sync schema with Supabase
    tables_to_sync = {'question_answer_attempts', 'question_answer_pairs'}
    
    for table_name, table_records in records_dict.items():
        if not table_records:
            print(f"No records to upsert for table {table_name}. Skipping.")
            continue
            
        print(f"Processing {len(table_records)} records for table: {table_name}")
        
        if table_name in tables_to_sync:
            print(f"Syncing schema for {table_name} with Supabase...")
            
            supabase_columns = set()
            try:
                result = supabase_client.table(table_name).select("*").limit(1).execute()
                if result.data and len(result.data) > 0:
                    supabase_columns = set(result.data[0].keys())
                    print(f"Found {len(supabase_columns)} columns in Supabase {table_name}")
            except Exception as e:
                print(f"Warning: Could not fetch Supabase schema for {table_name}: {e}")
            
            cursor.execute(f"PRAGMA table_info({table_name})")
            local_columns = {row[1] for row in cursor.fetchall()}
            
            missing_columns = supabase_columns - local_columns
            if missing_columns:
                print(f"Adding {len(missing_columns)} missing columns to local {table_name}: {missing_columns}")
                for col in missing_columns:
                    cursor.execute(f"ALTER TABLE {table_name} ADD COLUMN {col} TEXT")
                db.commit()
        
        if table_name == 'question_answer_pairs':
            for record in table_records:
                question_id = record.get('question_id')
                if not question_id:
                    continue
                
                cursor.execute(f"SELECT question_id FROM {table_name} WHERE question_id = ?", (question_id,))
                existing_record = cursor.fetchone()
                
                if existing_record:
                    record['question_vector'] = None
                    record['doc'] = None
                    record['k_nearest_neighbors'] = None
        
        columns = list(table_records[0].keys())
        column_names = ', '.join(columns)
        placeholders = ', '.join('?' * len(columns))
        
        upsert_sql = f"REPLACE INTO {table_name} ({column_names}) VALUES ({placeholders})"
        
        data_to_upsert = [
            tuple(record.get(col) for col in columns) for record in table_records
        ]
        
        try:
            cursor.executemany(upsert_sql, data_to_upsert)
            print(f"executemany command executed for {table_name}.")
            db.commit()
            print(f"Successfully committed {len(table_records)} records to {table_name}.")
        except sqlite3.Error as e:
            print(f"SQLite error during upsert for {table_name}: {e}")
            raise
    
    print("--- upsert_records_to_db finished ---")

def find_newest_timestamp(records: typing.Dict[str, typing.List[typing.Dict]]) -> typing.Union[str, None]:
    """
    Finds the newest timestamp across all tables in a records dictionary.
    For question_answer_pairs table, uses 'last_modified_timestamp'.
    For question_answer_attempts table, uses 'time_stamp'.
    Args:
        records: A dictionary with table names as keys and lists of record dictionaries as values.
    Returns:
        The string value of the newest timestamp, or None if no records exist.
    """
    if not records:
        return None
    
    newest_timestamp = None
    
    for table_name, table_records in records.items():
        if not table_records:
            continue
            
        # Determine which timestamp column to use
        timestamp_column = 'last_modified_timestamp' if table_name == 'question_answer_pairs' else 'time_stamp'
        
        # Find newest timestamp in this table
        table_newest = max(table_records, key=lambda x: x.get(timestamp_column, ''))
        table_newest_timestamp = table_newest.get(timestamp_column)
        
        # Compare with overall newest
        if table_newest_timestamp and (newest_timestamp is None or table_newest_timestamp > newest_timestamp):
            newest_timestamp = table_newest_timestamp
    
    return newest_timestamp

def fetch_new_records_from_supabase(supabase_client: supabase.Client, last_sync_date: str) -> dict:
    """
    Fetches all new records from both Supabase tables since the last sync date.
    This function uses a timestamp filter and pagination to retrieve all records
    that have been created or modified after the provided `last_sync_date`.
    Args:
        supabase_client: The initialized Supabase client object.
        last_sync_date: The timestamp string to filter records by. Records newer
                        than this timestamp will be returned.
    Returns:
        A dictionary with 'question_answer_pairs' and 'question_answer_attempts' keys,
        each containing a list of dictionaries representing rows from the respective tables.
    """
    def fetch_table_records(table_name: str, timestamp_column: str) -> list:
        all_records = []
        page_limit = 500
        offset = 0
        while True:
            response = (
                supabase_client.table(table_name)
                .select('*')
                .gt(timestamp_column, last_sync_date)
                .order(timestamp_column)
                .range(offset, offset + page_limit - 1)
                .execute()
            )
            page_data = response.data
            
            if not page_data:
                break
            
            all_records.extend(page_data)
            
            if len(page_data) < page_limit:
                break
            
            offset += page_limit
        return all_records
    
    return {
        'question_answer_pairs': fetch_table_records('question_answer_pairs', 'last_modified_timestamp'),
        'question_answer_attempts': fetch_table_records('question_answer_attempts', 'time_stamp')
    }

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
    """Returns an authenticated Supabase client session"""
    if SUPABASE_URL == "YOUR_SUPABASE_URL" or SUPABASE_KEY == "YOUR_SUPABASE_KEY":
        print("Error: Supabase credentials are not configured.")
        return None
    
    supabase_client = supabase.create_client(SUPABASE_URL, SUPABASE_KEY)
    
    supabase_client.auth.sign_in_with_password({
        "email": "aacra0820@gmail.com",
        "password": "Starting11Over!"
    })
    
    return supabase_client

def initialize_and_fetch_db(reset_question_vector=False, reset_doc=False) -> Connection:
    db: Connection = sqlite3.connect(DB_FILE)
    create_sql_table_if_not_exists(db)
    
    if reset_question_vector:
        print("Resetting all question_vector fields to null in local database...")
        try:
            cursor = db.cursor()
            cursor.execute("UPDATE question_answer_pairs SET question_vector = NULL")
            db.commit()
            print(f"Reset complete. Affected {cursor.rowcount} records.")
        except Exception as e:
            print(f"Error resetting question_vector fields in local DB: {e}")
            db.rollback()
    
    if reset_doc:
        print("Resetting all doc fields to null in local database...")
        try:
            cursor = db.cursor()
            cursor.execute("UPDATE question_answer_pairs SET doc = NULL")
            db.commit()
            print(f"Reset complete. Affected {cursor.rowcount} records.")
        except Exception as e:
            print(f"Error resetting doc fields in local DB: {e}")
            db.rollback()
    
    return db

def create_sql_table_if_not_exists(db) -> None:
    # Create question_answer_pairs table
    create_pairs_table_sql = """
    CREATE TABLE IF NOT EXISTS question_answer_pairs (
        question_id TEXT NOT NULL PRIMARY KEY,
        time_stamp TEXT,
        citation TEXT,
        question_elements TEXT NOT NULL,
        answer_elements TEXT NOT NULL,
        concepts TEXT,
        subjects TEXT,
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
    
    # Create question_answer_attempts table
    create_attempts_table_sql = """
    CREATE TABLE IF NOT EXISTS question_answer_attempts (
        time_stamp TEXT NOT NULL,
        question_id TEXT NOT NULL,
        participant_id TEXT NOT NULL,
        avg_react_time REAL NOT NULL,
        response_result INTEGER NOT NULL,
        was_first_attempt INTEGER NOT NULL,
        last_revised_date TEXT,
        days_since_last_revision REAL,
        total_attempts INTEGER NOT NULL,
        revision_streak INTEGER NOT NULL,
        question_vector TEXT,
        question_type TEXT,
        num_mcq_options INTEGER DEFAULT 0,
        num_so_options INTEGER DEFAULT 0,
        num_sata_options INTEGER DEFAULT 0,
        num_blanks INTEGER DEFAULT 0,
        total_correct_attempts INTEGER,
        total_incorrect_attempts INTEGER,
        accuracy_rate REAL,
        time_of_presentation TEXT,
        days_since_first_introduced REAL,
        attempt_day_ratio REAL,
        user_stats_vector TEXT,
        module_performance_vector TEXT,
        user_profile_record TEXT,
        PRIMARY KEY (time_stamp, question_id, participant_id)
    );
    """
    
    cursor = db.cursor()
    cursor.execute(create_pairs_table_sql)
    cursor.execute(create_attempts_table_sql)

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

def sync_vectors_to_supabase(reset_question_vector=False, reset_attempts_vector=False):
    """
    Syncs question_vector data from local database to Supabase.
    Only updates records that are missing question_vector on Supabase.
    Continues until all records on Supabase have been updated or no more can be updated.
    
    Args:
        reset_question_vector: If True, sets all question_vector fields to null in question_answer_pairs before syncing
        reset_attempts_vector: If True, sets all question_vector fields to null in question_answer_attempts before syncing
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
    
    # Reset question_vector fields if requested
    if reset_question_vector:
        print("Resetting question_vector fields in question_answer_pairs...")
        try:
            supabase_client.table('question_answer_pairs').update({'question_vector': None}).neq('question_id', '').execute()
            print("Reset complete for question_answer_pairs")
        except Exception as e:
            print(f"Error resetting question_answer_pairs: {e}")
            return False
    
    if reset_attempts_vector:
        print("Resetting question_vector fields in question_answer_attempts...")
        try:
            supabase_client.table('question_answer_attempts').update({'question_vector': None}).neq('question_id', '').execute()
            print("Reset complete for question_answer_attempts")
        except Exception as e:
            print(f"Error resetting question_answer_attempts: {e}")
            return False
    
    cursor = db.cursor()
    
    try:
        # Sync question_answer_pairs
        total_pairs = 0
        print("Syncing question_answer_pairs...")
        while True:
            response = supabase_client.table('question_answer_pairs').select('question_id').is_('question_vector', 'null').limit(100).execute()
            if not response.data:
                print(f"Sync complete for question_answer_pairs. Total records updated: {total_pairs}")
                break
                
            missing_question_ids = [record['question_id'] for record in response.data]
            print(f"Found {len(missing_question_ids)} records missing question_vector in question_answer_pairs")
            
            batch_updated = 0
            for record in response.data:
                question_id = record['question_id']
                cursor.execute("SELECT question_vector FROM question_answer_pairs WHERE question_id = ?", (question_id,))
                local_record = cursor.fetchone()
                
                if local_record and local_record[0]:
                    try:
                        supabase_client.table('question_answer_pairs').update({'question_vector': local_record[0]}).eq('question_id', question_id).execute()
                        batch_updated += 1
                        print(f"Updated question_vector for question_id: {question_id}")
                    except Exception as e:
                        print(f"Error updating pairs {question_id}: {e}")
            
            total_pairs += batch_updated
            print(f"Batch complete for question_answer_pairs. Updated {batch_updated} records in this batch.")
            if batch_updated == 0:
                print("No more records could be updated in question_answer_pairs. Stopping sync for this table.")
                break
        
        # Sync question_answer_attempts with same vectors
        total_attempts = 0
        print("Syncing question_answer_attempts...")
        while True:
            response = supabase_client.table('question_answer_attempts').select('time_stamp, question_id, participant_id').is_('question_vector', 'null').limit(100).execute()
            if not response.data:
                print(f"Sync complete for question_answer_attempts. Total records updated: {total_attempts}")
                break
                
            print(f"Found {len(response.data)} records missing question_vector in question_answer_attempts")
            
            batch_updated = 0
            for record in response.data:
                question_id = record['question_id']
                cursor.execute("SELECT question_vector FROM question_answer_pairs WHERE question_id = ?", (question_id,))
                local_record = cursor.fetchone()
                
                if local_record and local_record[0]:
                    try:
                        supabase_client.table('question_answer_attempts').update({'question_vector': local_record[0]}).eq('time_stamp', record['time_stamp']).eq('question_id', record['question_id']).eq('participant_id', record['participant_id']).execute()
                        batch_updated += 1
                        print(f"Updated question_vector for attempt: {record['time_stamp']}, {question_id}, {record['participant_id']}")
                    except Exception as e:
                        print(f"Error updating attempts record: {e}")
            
            total_attempts += batch_updated
            print(f"Batch complete for question_answer_attempts. Updated {batch_updated} records in this batch.")
            if batch_updated == 0:
                print("No more records could be updated in question_answer_attempts. Stopping sync for this table.")
                break
        
        print(f"Sync complete. Pairs: {total_pairs}, Attempts: {total_attempts}")
        return True
        
    except Exception as e:
        print(f"Error during sync: {e}")
        return False
    
    finally:
        if db:
            db.close()

def fetch_data_for_bertopic(db: Connection):
    """
    Fetches documents, embeddings, and IDs for BERTopic processing.
    """
    cursor = db.cursor()
    
    cursor.execute("""
        SELECT question_id, doc, question_vector 
        FROM question_answer_pairs 
        WHERE doc IS NOT NULL AND doc != '' 
        AND question_vector IS NOT NULL AND question_vector != ''
        ORDER BY question_id
    """)
    
    rows = cursor.fetchall()
    
    if not rows:
        print("No records with both doc and question_vector found!")
        return [], [], None
    
    question_ids = [row[0] for row in rows]
    docs = [row[1] for row in rows]
    embeddings = [json.loads(row[2]) for row in rows]
    embeddings = np.array(embeddings)
    
    print(f"Fetched {len(docs)} documents with pre-computed embeddings")
    
    return docs, embeddings, question_ids 

def fetch_and_insert_missing_records(db, supabase_client, question_ids):
    """
    Fetches missing records from Supabase and inserts them into the local database.
    Used to ensure all records on the server are available locally for analysis.
    
    Args:
        db: SQLite database connection
        supabase_client: Authenticated Supabase client
        question_ids: List of question_ids that are missing locally
        
    Returns:
        int: Number of records fetched and inserted
    """
    cursor = db.cursor()
    total_inserted = 0
    
    if not question_ids:
        print("No missing records to fetch.")
        return 0
    
    print(f"Fetching {len(question_ids)} missing records from Supabase...")
    
    # Process in batches to avoid too many requests
    batch_size = 100
    for i in range(0, len(question_ids), batch_size):
        batch_ids = question_ids[i:i + batch_size]
        
        try:
            # Fetch the missing records from Supabase
            response = supabase_client.table('question_answer_pairs')\
                .select('*')\
                .in_('question_id', batch_ids)\
                .execute()
            
            if not response.data:
                print(f"No data returned for batch {i//batch_size + 1}")
                continue
            
            # Prepare records for insertion
            records = []
            for record in response.data:
                # Ensure required fields are present
                if 'question_id' not in record:
                    continue
                
                # Convert to format compatible with upsert_records_to_db
                processed_record = {}
                for key, value in record.items():
                    if value is None:
                        processed_record[key] = None
                    elif isinstance(value, dict) or isinstance(value, list):
                        processed_record[key] = json.dumps(value)
                    else:
                        processed_record[key] = value
                
                # Set vector fields to None since they'll be computed locally
                processed_record['question_vector'] = None
                processed_record['doc'] = None
                processed_record['k_nearest_neighbors'] = None
                
                records.append(processed_record)
            
            if records:
                # Use existing upsert_records_to_db function
                records_dict = {'question_answer_pairs': records}
                cursor.execute("BEGIN TRANSACTION")
                
                # Insert each record individually
                for record in records:
                    # Check if record already exists (shouldn't, but just in case)
                    cursor.execute(
                        "SELECT question_id FROM question_answer_pairs WHERE question_id = ?",
                        (record['question_id'],)
                    )
                    
                    if cursor.fetchone():
                        # Update existing record (just in case)
                        update_fields = []
                        update_values = []
                        for key, value in record.items():
                            if key != 'question_id':
                                update_fields.append(f"{key} = ?")
                                update_values.append(value)
                        
                        if update_fields:
                            update_values.append(record['question_id'])
                            query = f"""
                                UPDATE question_answer_pairs 
                                SET {', '.join(update_fields)}
                                WHERE question_id = ?
                            """
                            cursor.execute(query, update_values)
                    else:
                        # Insert new record
                        columns = [key for key in record.keys() if key != 'question_id']
                        columns_str = ', '.join(columns)
                        placeholders = ', '.join(['?' for _ in columns])
                        
                        query = f"""
                            INSERT INTO question_answer_pairs (question_id, {columns_str})
                            VALUES (?, {placeholders})
                        """
                        values = [record['question_id']] + [record[col] for col in columns]
                        cursor.execute(query, values)
                
                db.commit()
                total_inserted += len(records)
                print(f"Batch {i//batch_size + 1}: Inserted {len(records)} records")
            
        except Exception as e:
            print(f"Error fetching/inserting batch {i//batch_size + 1}: {e}")
            db.rollback()
            continue
    
    print(f"Total records fetched and inserted: {total_inserted}")
    return total_inserted

def sync_knn_results_to_supabase(db, supabase_client, changed_records, timestamp):
    """
    Syncs ONLY k_nearest_neighbors data from local database to Supabase using batch operations.
    
    Args:
        db: SQLite database connection
        supabase_client: Authenticated Supabase client
        changed_records: list of question_ids that have changed KNN vectors
        timestamp: ISO timestamp string to use for 'last_modified_timestamp' field
    """
    cursor = db.cursor()
    total_updated = 0
    
    # PART 1: Reset changed records to null in Supabase
    if changed_records:
        random.shuffle(changed_records)
        if len(changed_records) > 1000:
            changed_records = changed_records[:1000]
            print(f"Limited to {len(changed_records)} records for resetting")

        print(f"Resetting {len(changed_records)} changed records to null in Supabase...")
        batch_size = 100
        for i in range(0, len(changed_records), batch_size):
            batch_ids = changed_records[i:i+batch_size]
            
            # BATCH UPDATE: Set only k_nearest_neighbors to null for these IDs
            # DO NOT update timestamp here - keeps the main app (NOT THE PIPELINE) from pulling null values unnecessarily
            supabase_client.table('question_answer_pairs')\
                .update({'k_nearest_neighbors': None})\
                .in_('question_id', batch_ids)\
                .execute()
            
            print(f"Reset {len(batch_ids)} records in one batch")
        
        print(f"Reset complete. {len(changed_records)} records set to null in Supabase")
    
    print("Starting k-NN sync (filling nulls from local DB)...")

    # PART 2: Find and fill null KNN values in batches
    while True:
        # Find records with null k_nearest_neighbors
        response = supabase_client.table('question_answer_pairs')\
            .select('question_id')\
            .is_('k_nearest_neighbors', 'null')\
            .limit(100)\
            .execute()
        
        if not response.data:
            print(f"Sync complete. Total records updated: {total_updated}")
            break
        
        question_ids = [record['question_id'] for record in response.data]
        print(f"Found {len(question_ids)} records with null k_nearest_neighbors")
        
        if not question_ids:
            break
        
        # Get local KNN data for these IDs
        placeholders = ','.join('?' * len(question_ids))
        cursor.execute(f"""
            SELECT question_id, k_nearest_neighbors 
            FROM question_answer_pairs 
            WHERE question_id IN ({placeholders}) 
            AND k_nearest_neighbors IS NOT NULL
        """, question_ids)
        
        local_records = cursor.fetchall()
        
        # NEW: Check if we're missing any records locally
        local_question_ids = {record[0] for record in local_records}
        missing_ids = [qid for qid in question_ids if qid not in local_question_ids]
        
        if missing_ids:
            print(f"Found {len(missing_ids)} records missing locally. Fetching from server...")
            fetch_and_insert_missing_records(db, supabase_client, missing_ids)
            
            # Try fetching again after inserting missing records
            cursor.execute(f"""
                SELECT question_id, k_nearest_neighbors 
                FROM question_answer_pairs 
                WHERE question_id IN ({placeholders}) 
                AND k_nearest_neighbors IS NOT NULL
            """, question_ids)
            local_records = cursor.fetchall()
        
        if not local_records:
            print("No matching KNN data found locally. Stopping sync.")
            break
        
        # Process in batches - update each record individually but still using batch operations
        batch_updated = 0
        for question_id, knn_data in local_records:
            # Update single record with BOTH k_nearest_neighbors AND timestamp
            supabase_client.table('question_answer_pairs')\
                .update({
                    'k_nearest_neighbors': knn_data,
                    'last_modified_timestamp': timestamp
                })\
                .eq('question_id', question_id)\
                .execute()
            
            batch_updated += 1
            total_updated += 1
        
        print(f"Updated {batch_updated} records in this batch")
        
        if len(question_ids) < 100:
            print("Last batch processed. Stopping sync.")
            break
    
    print(f"k-NN sync finished. Total records updated: {total_updated}")
    return total_updated

def clean_deleted_records_locally(db, supabase_client, batch_size=500):
    """
    Removes local records that no longer exist on Supabase server.
    Fetches all existing question_ids from Supabase first, then compares locally.
    
    Args:
        db: SQLite database connection
        supabase_client: Authenticated Supabase client
        batch_size: Number of records to fetch from Supabase at a time
    
    Returns:
        tuple: (deleted_pairs_count, deleted_attempts_count)
    """
    cursor = db.cursor()
    
    # Get total count for reporting
    cursor.execute("SELECT COUNT(*) FROM question_answer_pairs")
    total_local_pairs = cursor.fetchone()[0]
    
    cursor.execute("SELECT COUNT(*) FROM question_answer_attempts")
    total_local_attempts = cursor.fetchone()[0]
    
    print(f"Checking for deleted records. Local: {total_local_pairs} question pairs, {total_local_attempts} attempts")
    
    # STEP 1: Fetch ALL existing question_ids from Supabase (server-side)
    print("Fetching existing question IDs from Supabase...")
    existing_ids = set()
    offset = 0
    
    while True:
        response = supabase_client.table('question_answer_pairs')\
            .select('question_id')\
            .order('question_id')\
            .range(offset, offset + batch_size - 1)\
            .execute()
        
        if not response.data:
            break
            
        existing_ids.update(record['question_id'] for record in response.data)
        offset += batch_size
        print(f"Fetched {len(existing_ids)} IDs so far...")
    
    print(f"Total existing records on server: {len(existing_ids)}")
    
    # STEP 2: Process local records in batches and delete those not in existing_ids
    deleted_pairs_count = 0
    deleted_attempts_count = 0
    offset = 0
    
    while True:
        cursor.execute("""
            SELECT question_id FROM question_answer_pairs 
            LIMIT ? OFFSET ?
        """, (batch_size, offset))
        
        batch = cursor.fetchall()
        if not batch:
            break
            
        local_ids = [row[0] for row in batch]
        deleted_ids = [qid for qid in local_ids if qid not in existing_ids]
        
        # Delete local records that don't exist on server
        if deleted_ids:
            placeholders = ','.join('?' * len(deleted_ids))
            
            # Delete from question_answer_pairs
            cursor.execute(f"""
                DELETE FROM question_answer_pairs 
                WHERE question_id IN ({placeholders})
            """, deleted_ids)
            deleted_pairs_count += cursor.rowcount
            
            # Delete from question_answer_attempts
            cursor.execute(f"""
                DELETE FROM question_answer_attempts 
                WHERE question_id IN ({placeholders})
            """, deleted_ids)
            deleted_attempts_count += cursor.rowcount
        
        offset += batch_size
    
    db.commit()
    
    print(f"Cleanup complete. Deleted:")
    print(f"  - {deleted_pairs_count} question pairs")
    print(f"  - {deleted_attempts_count} attempt records")
    
    return deleted_pairs_count, deleted_attempts_count

def save_changed_records(changed_records, filename="changed_records.json"):
    """
    Saves the list of changed record IDs directly to a local JSON file.
    
    Args:
        changed_records: List of question_ids that have changed
        filename: Name of the JSON file to save to (default: "changed_records.json")
    """
    with open(filename, 'w') as f:
        json.dump(changed_records, f)  # Save the list directly
    
    print(f"Saved {len(changed_records)} changed records to {filename}")

def load_changed_records(filename="changed_records.json"):
    """
    Loads the list of changed record IDs directly from a local JSON file.
    
    Args:
        filename: Name of the JSON file to load from (default: "changed_records.json")
    
    Returns:
        List of changed record IDs, or empty list if file doesn't exist or is invalid
    """
    if not os.path.exists(filename):
        return []
    
    with open(filename, 'r') as f:
        try:
            data = json.load(f)
            # Ensure we return a list (the saved data should be a list)
            return data if isinstance(data, list) else []
        except json.JSONDecodeError:
            return []

def main():
    fetch_and_save_data_locally()



if __name__ == "__main__":
    main()