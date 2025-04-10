

The old code base had a sync function as follows:
```python
def list_local_media_files():
    """
    Returns a list of all file names in the 'system_data/media_files/' directory.
    """
    local_directory = "system_data/media_files/"
    file_names = os.listdir(local_directory)
    return file_names
def is_server_update_newer(last_server_update, last_local_update):
    """
    Checks if the last server update is newer than the last local update.
    """
    try:
        # Convert ISO 8601 strings to datetime objects

        server_update_time = datetime.fromisoformat(last_server_update.rstrip("Z"))
        local_update_time = datetime.fromisoformat(last_local_update.rstrip("Z"))
        print("Last server update followed by Last local update")
        print(server_update_time)
        print(local_update_time)
        # Compare the two datetime objects
        is_newer = server_update_time > local_update_time
        if is_newer == True:
            print("User Profile on Server is newer than one on Local Device")
        else:
            print("User Profile on Server is up to date")
        return is_newer
    except ValueError as e:
        print(f"Error parsing update times: {e}")
        return False
def sync_local_data_with_cloud_data(CURRENT_USER):
    '''
    Syncs cloud data with local database
    Returns None
    '''
    # First Sync the Question Database
    question_timestamp_log = firestore_db.get_question_object_data_timestamps_from_firestore()
    question_object_data = get_question_object_data()
    for info_block in question_timestamp_log:
        question_id         = info_block["doc_id"]
        cloud_time_stamp    = info_block["updateTime"]
        # If the question exists in the cloud database, but not locally, get the question object from the cloud and write it to the local json
        if question_object_data.get(question_id) == None:
            question_object = firestore_db.get_specific_question_from_firestore(question_id)
            question_object_data[question_id] = question_object
            continue
        local_time_stamp = question_object_data[question_id]["updateTime"]
        if local_time_stamp != cloud_time_stamp: # Update the local object with cloud object
            question_object_data[question_id] = firestore_db.get_specific_question_from_firestore(question_id)
    update_question_object_data(question_object_data)
    # Second Sync any media files (Was 1 read per image in the server, now no read operations take place at all)
    media_files = []
    for question_id, question_object in question_object_data.items():
        if question_object == None:
            continue
        field_hit = False
        media_one = question_object["question_image"]
        media_two = question_object["answer_image"]
        if media_one != None:
            media_files.append(media_one)
        if media_two != None:
            media_files.append(media_two)

    # Remove Duplicates
    media_files = set(media_files)
    media_files = list(media_files)
    # Get list of locally stored files
    local_files = list_local_media_files()
    for file_name in media_files:
        if file_name not in local_files:
            firestore_db.get_media_file_from_firestore(file_name)
    # Third Sync User Data, if User Data in cloud is newer than local User Data
    last_server_update  = firestore_db.get_user_profile_last_update_property_from_firestore(CURRENT_USER)
    try:
        # Last update is stored locally, file will not exist, if the user_profile has never been updated on that device
        with open(f"system_data/user_profiles/{CURRENT_USER}/last_user_update.json", "r") as f:
            last_local_update = json.load(f)
        if is_server_update_newer(last_server_update, last_local_update) == True:
            firestore_db.get_user_profile_from_firestore(CURRENT_USER)
            # Ensure the last_server update property matches when we hit this condition
            user_profile_data = get_user_data(CURRENT_USER)
            update_user_profile(user_profile_data)
    except FileNotFoundError:
        firestore_db.get_user_profile_from_firestore(CURRENT_USER)
        # Ensure the last_server update property matches when we hit this condition
        user_profile_data = get_user_data(CURRENT_USER)
        update_user_profile(user_profile_data)
```
