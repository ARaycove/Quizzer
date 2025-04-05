import requests
import json
from itertools import islice
import time
import threading
import os
def fetch_firestore_server_time():
    """
    Fetches the Firestore server time using a simple request.
    """
    pass
    # # Firestore metadata endpoint (using any valid collection)
    # project_id = "quizzer-d70f1"
    # api_key = "AIzaSyAWKaMkZiBzbBrcrp22-azTtnlrqqey-YA"
    # url = f"https://firestore.googleapis.com/v1/projects/{project_id}/databases/(default)/documents"
    # headers = {"Content-Type": "application/json"}
    # params = {"key": api_key}

    # # Make a GET request to fetch Firestore metadata
    # response = requests.get(url, headers=headers, params=params)
    # if response.status_code == 200:
    #     data = response.json()
    #     return data.get("readTime")  # Extract the server time
    # else:
    #     print(f"Error fetching server time: {response.status_code}, {response.text}")
    #     return None

def convert_firestore_fields(fields):
    """
    Converts Firestore fields to a simplified dictionary format.
    """
    pass
    # def extract_value(field):
    #     """
    #     Extracts the actual value from a Firestore field type.
    #     """
    #     if "stringValue" in field:
    #         return field["stringValue"]
    #     elif "integerValue" in field:
    #         return int(field["integerValue"])
    #     elif "doubleValue" in field:
    #         return float(field["doubleValue"])
    #     elif "booleanValue" in field:
    #         return field["booleanValue"]
    #     elif "nullValue" in field:
    #         return None
    #     elif "arrayValue" in field:
    #         # Extract array values recursively
    #         return [extract_value(value) for value in field["arrayValue"].get("values", [])]
    #     elif "mapValue" in field:
    #         # Extract map values recursively
    #         return convert_firestore_fields(field["mapValue"]["fields"])
    #     else:
    #         raise ValueError(f"Unsupported Firestore field type: {field}")

    # # Convert all fields
    # return {key: extract_value(value) for key, value in fields.items()}      
def test_api():
    pass
    # project_id = "quizzer-d70f1"
    # api_key = "AIzaSyAWKaMkZiBzbBrcrp22-azTtnlrqqey-YA"
    # BASE_URL = f"https://firestore.googleapis.com/v1/projects/{project_id}/databases/(default)/documents"
    # # Test writing a single document
    # test_document = {
    #     "fields": {
    #         "name": {"stringValue": "Test Document"},
    #         "value": {"integerValue": 42}
    #     }
    # }
    # response = requests.post(
    #     f"{BASE_URL}/test_collection",
    #     headers={"Content-Type": "application/json"},
    #     json=test_document,
    #     params={"key": api_key}
    # )
    # print(response.status_code, response.text)
def format_value(value):
    """
    Formats a value to match Firestore's data structure requirements.
    Args:
        value: The value to format.
    Returns:
        dict: The formatted value.
    """
    pass
    # if isinstance(value, str):
    #     return {"stringValue": value}
    # elif isinstance(value, int):
    #     return {"integerValue": value}
    # elif isinstance(value, float):
    #     return {"doubleValue": value}
    # elif isinstance(value, bool):
    #     return {"booleanValue": value}
    # elif isinstance(value, dict):
    #     return {"mapValue": {"fields": {k: format_value(v) for k, v in value.items()}}}
    # elif isinstance(value, list):
    #     return {"arrayValue": {"values": [format_value(v) for v in value]}}
    # else:
    #     return {"nullValue": None}

def create_user(email, password):
    # Firebase sign-up endpoint
    pass
    # api_key = "AIzaSyAWKaMkZiBzbBrcrp22-azTtnlrqqey-YA"
    # url = f"https://identitytoolkit.googleapis.com/v1/accounts:signUp?key={api_key}"

    # # Data to send to the API
    # payload = {
    #     "email": email,
    #     "password": password,
    #     "returnSecureToken": True  # Indicates we want a Firebase Auth token in the response
    # }

    # # Make the request to Firebase
    # response = requests.post(url, json=payload)

    # # Handle the response
    # if response.status_code == 200:
    #     print("User created successfully!")
    #     print("Response:", response.json())
    # else:
    #     print("Error creating user:")
    #     print("Response:", response.json())

def authenticate(email_submission, password_submission):
    pass
    # auth_url = "https://www.googleapis.com/identitytoolkit/v3/relyingparty/verifyPassword?key="
    # api_key = "AIzaSyAWKaMkZiBzbBrcrp22-azTtnlrqqey-YA"
    
    # payload = {
    #     "email": email_submission,
    #     "password": password_submission,
    #     "returnSecureToken": True
    # }
    # response = requests.post(auth_url + api_key, json=payload)
    # return response.status_code
def get_question_object_data_timestamps_from_firestore():
    pass
    # project_id = "quizzer-d70f1"
    # api_key = "AIzaSyAWKaMkZiBzbBrcrp22-azTtnlrqqey-YA"
    # collection_name = "question_object_index"
    # base_url = f"https://firestore.googleapis.com/v1/projects/{project_id}/databases/(default)/documents/{collection_name}"
    # headers = {"Content-Type": "application/json"}
    # metadata_list = []
    # next_page_token = None

    # while True:
    #     params = {"key": api_key}
    #     if next_page_token:
    #         params["pageToken"] = next_page_token

    #     response = requests.get(base_url, headers=headers, params=params)
    #     if response.status_code != 200:
    #         print(f"Error fetching index documents: {response.status_code}, {response.text}")
    #         break

    #     data = response.json()
    #     documents = data.get("documents", [])
    #     for doc in documents:
    #         fields = doc.get("fields", {})
    #         for doc_id, details in fields.items():
    #             update_time = details.get("timestampValue")
    #             metadata_list.append({"doc_id": doc_id, "updateTime": update_time})

    #     # Check for pagination
    #     next_page_token = data.get("nextPageToken")
    #     if not next_page_token:
    #         break

    # return metadata_list
def get_user_profile_last_update_property_from_firestore(current_user_name):
    return None
    """
    Fetches the metadata of the user's data file from Firebase Storage to determine the last update time.
    """
    bucket_name = "quizzer-d70f1.firebasestorage.app"
    subfolder = "user_profiles"
    api_key = "AIzaSyAWKaMkZiBzbBrcrp22-azTtnlrqqey-YA"
    file_path = f"{subfolder}/{current_user_name}_data.json"
    encoded_file_path = file_path.replace("/", "%2F")
    metadata_url = f"https://firebasestorage.googleapis.com/v0/b/{bucket_name}/o/{encoded_file_path}?key={api_key}"
    response = requests.get(metadata_url)
    if response.status_code == 200:
        try:
            metadata = response.json()
            last_updated = metadata.get("updated")  # Extract the 'updated' field
            if last_updated:
                return last_updated
            else:
                print("Metadata does not contain 'updated' field.")
                return None
        except json.JSONDecodeError as e:
            print(f"Error decoding metadata JSON: {e}")
            return None
    else:
        print(f"Error fetching file metadata: {response.status_code} - {response.text}")
        return None
def get_user_profile_from_firestore(current_user_name):
    return None
    """
    Gets the user's data JSON file from Firebase Storage and saves it locally.
    """
    bucket_name = "quizzer-d70f1.firebasestorage.app"
    subfolder = "user_profiles"
    api_key = "AIzaSyAWKaMkZiBzbBrcrp22-azTtnlrqqey-YA"
    file_path = f"{subfolder}/{current_user_name}_data.json"
    encoded_file_path = file_path.replace("/", "%2F")
    file_url = f"https://firebasestorage.googleapis.com/v0/b/{bucket_name}/o/{encoded_file_path}?alt=media&key={api_key}"
    local_directory = f"system_data/user_profiles/{current_user_name}/"
    local_file_path = os.path.join(local_directory, f"{current_user_name}_data.json")

    os.makedirs(local_directory, exist_ok=True)

    response = requests.get(file_url, stream=True)
    last_server_update  = get_user_profile_last_update_property_from_firestore(current_user_name)
    with open(f"system_data/user_profiles/{current_user_name}/last_user_update.json", "w+") as f:
        json.dump(last_server_update, f)
    if response.status_code == 200:
        try:
            with open(local_file_path, "wb") as file:
                for chunk in response.iter_content(chunk_size=8192):
                    file.write(chunk)
            print(f"File downloaded successfully: {local_file_path}")
            return True
        except Exception as e:
            print(f"Error saving file: {e}")
            return False
    else:
        print(f"Error fetching user profile: {response.status_code} - {response.text}")
        return False
    

def write_user_profile_to_firestore(CURRENT_USER):
    return None
    """
    Reads a user's local data file and uploads it to Firebase Storage, overwriting the existing file.
    """
    def update_profile():
        time.sleep(2)
        bucket_name = "quizzer-d70f1.firebasestorage.app"
        subfolder = "user_profiles"
        api_key = "AIzaSyAWKaMkZiBzbBrcrp22-azTtnlrqqey-YA"
        file_path = f"{subfolder}/{CURRENT_USER}_data.json"
        encoded_file_path = file_path.replace("/", "%2F")
        file_url = f"https://firebasestorage.googleapis.com/v0/b/{bucket_name}/o/{encoded_file_path}?uploadType=media&key={api_key}"
        # Read and upload the local file
        try:
            with open(f"system_data/user_profiles/{CURRENT_USER}/{CURRENT_USER}_data.json", "rb") as file:  # Use binary mode for upload
                user_profile_data = file.read()
            headers = {"Content-Type": "application/json"}
            response = requests.post(file_url, headers=headers, data=user_profile_data)
            # Handle the response
            if response.status_code in (200, 201):  # 201 for new files, 200 for overwrites
                print(f"User data for {CURRENT_USER} uploaded successfully.")
            else:
                print(f"Error uploading user data: {response.status_code} - {response.text}")
        except FileNotFoundError:
            print(f"Error: Local file not found.")
        except Exception as e:
            print(f"Error during upload: {e}")
        time.sleep(2)
        last_server_update  = get_user_profile_last_update_property_from_firestore(CURRENT_USER)
        with open(f"system_data/user_profiles/{CURRENT_USER}/last_user_update.json", "w+") as f:
            json.dump(last_server_update, f)
    thread_op = threading.Thread(target=update_profile)
    thread_op.start()
    
def get_specific_question_from_firestore(doc_id):
    print(f"Fetching question {doc_id} from Firestore")
    project_id = "quizzer-d70f1"
    api_key = "AIzaSyAWKaMkZiBzbBrcrp22-azTtnlrqqey-YA"
    collection_name = "question_object_data"

    url = f"https://firestore.googleapis.com/v1/projects/{project_id}/databases/(default)/documents/{collection_name}/{doc_id}"
    headers = {"Content-Type": "application/json"}
    params = {"key": api_key}

    # Make the GET request to fetch the document
    response = requests.get(url, headers=headers, params=params)
    if response.status_code == 200:
        raw_data = response.json()
        # Transform the response to the desired format
        # try:
        fields = raw_data.get("fields", {})
        transformed_data = {
            "subject": eval(fields["subject"]["stringValue"]) if "subject" in fields else [],
            "related": eval(fields["related"]["stringValue"]) if "related" in fields else [],
            "question_text": fields.get("question_text", {}).get("stringValue", None),
            "answer_text": fields.get("answer_text", {}).get("stringValue", None),
            "question_image": fields.get("question_image", {}).get("stringValue", None) or None,
            "answer_image": fields.get("answer_image", {}).get("stringValue", None) or None,
            "question_audio": fields.get("question_audio", {}).get("stringValue", None) or None,
            "question_video": fields.get("question_video", {}).get("stringValue", None) or None,
            "answer_audio": fields.get("answer_audio", {}).get("stringValue", None) or None,
            "answer_video": fields.get("answer_video", {}).get("stringValue", None) or None,
            "module_name": fields.get("module_name", {}).get("stringValue", None),
            # "academic_sources": eval(fields["academic_sources"]["stringValue"]) if "academic_sources" in fields else [],
            "id": fields.get("id", {}).get("stringValue", None),
            "primary_subject": fields.get("primary_subject", {}).get("stringValue", None),
            "updateTime": raw_data.get("updateTime", None),
            "index_id": fields.get("index_id", {}).get("stringValue", None),
        }
        return transformed_data
        # except Exception as e:
        #     print(f"Error transforming Firestore response: {e}")
        #     return None
    else:
        print(f"Error fetching document {doc_id}: {response.status_code}, {response.text}")
        return None
    
def update_question_in_firestore(doc_id, updated_data):
    """
    Updates a specific document in Firestore, secondarily updates the doc_id: updateTime index
    """
    return updated_data
    if updated_data == None:
        return ""
    print(f"Updating question {doc_id} in Firestore")
    project_id = "quizzer-d70f1"
    api_key = "AIzaSyAWKaMkZiBzbBrcrp22-azTtnlrqqey-YA"
    collection_name = "question_object_data"

    index_id = updated_data.get("index_id")
    if index_id == None:
        print(f"Document {doc_id} has no index_id; determining appropriate index.")
        index_id = determine_index_id(doc_id)
        if index_id is None:
            print("Failed to determine index_id. Aborting operation.")
            return None
        updated_data["index_id"] = index_id  # Add index_id to the updated data


    url = f"https://firestore.googleapis.com/v1/projects/{project_id}/databases/(default)/documents/{collection_name}/{doc_id}?key={api_key}"
    headers = {"Content-Type": "application/json"}

    # Wrap the updated_data in Firestore's expected "fields" structure
    firestore_data = {"fields": {key: {"stringValue": str(value)} for key, value in updated_data.items()}}

    # Make the PATCH request to update the document
    response = requests.patch(url, headers=headers, json=firestore_data)
    response = response.json()
    update_question_index_in_firestore(response)
    updated_data["updateTime"] = response["updateTime"]
    question_object = updated_data
    return question_object

def determine_index_id(doc_id):
    """
    Determines which index document the given question should belong to, creating a new index if necessary.
    """
    project_id = "quizzer-d70f1"
    api_key = "AIzaSyAWKaMkZiBzbBrcrp22-azTtnlrqqey-YA"
    index_collection    = "question_object_index"
    index_prefix        = "question_index"

    index_suffix = 1 #FIXME update this periodically to prevent unneccessary read operations
    while True:
        index_doc_name = f"{index_prefix}_{index_suffix}"
        url = f"https://firestore.googleapis.com/v1/projects/{project_id}/databases/(default)/documents/{index_collection}/{index_doc_name}?key={api_key}"
        headers = {"Content-Type": "application/json"}

        response = requests.get(url, headers=headers)
        if response.status_code == 404:
            print(f"Creating new index document: {index_doc_name:15}")
            index_data = {"fields": {doc_id: {"stringValue": "placeholder"}}}
            create_response = requests.patch(url, headers=headers, json=index_data)
            if create_response.status_code in (200, 204):
                return index_doc_name
            else:
                print(f"Error creating index document: {create_response.status_code}, {create_response.text}")
                return None
        elif response.status_code == 200:
            index_doc = response.json()
            fields = index_doc.get("fields", {})
            if len(fields) < 4500:  # Maximum capacity per index document
                return index_doc_name
            else:
                index_suffix += 1  # Move to the next index
        else:
            print(f"Error fetching index document: {response.status_code}, {response.text}")
            return None
def update_question_index_in_firestore(response):
    """
    Updates the corresponding index document with the doc_id and updateTime.
    """
    if not response:
        print("No response provided. Cannot update index.")
        return
        # Extract necessary information from the response
    doc_id = response["fields"]["id"]["stringValue"]
    update_time = response["updateTime"]
    index_id = response["fields"]["index_id"]["stringValue"]

    # Wrap doc_id in backticks to make it a valid field path
    escaped_doc_id = f"`{doc_id}`"

    # Firestore setup
    project_id = "quizzer-d70f1"
    api_key = "AIzaSyAWKaMkZiBzbBrcrp22-azTtnlrqqey-YA"
    index_collection = "question_object_index"

    # Update the specific field in the index document
    url = f"https://firestore.googleapis.com/v1/projects/{project_id}/databases/(default)/documents/{index_collection}/{index_id}?key={api_key}"
    headers = {"Content-Type": "application/json"}
    update_data = {
        "fields": {
            doc_id: {"timestampValue": update_time}
        }
    }
    # Use the updateMask query parameter to target only the specific field
    params = {"updateMask.fieldPaths": escaped_doc_id}

    response = requests.patch(url, headers=headers, json=update_data, params=params)
    if response.status_code in (200, 204):
        print(f"Index {index_id} successfully updated with document {doc_id} at {update_time}.")
    else:
        print(f"Error updating index document {index_id}: {response.status_code}, {response.text}")

def get_media_file_names():
    """
    Gets a list of file names in the 'media_files/' directory from the Google Cloud Storage bucket.
    """
    def get_index(string_value: str):
        return string_value.find("/")
    # Firebase Storage bucket details
    bucket_name = "quizzer-d70f1.firebasestorage.app"
    base_url = f"https://firebasestorage.googleapis.com/v0/b/{bucket_name}/o"
    headers = {"Content-Type": "application/json"}
    params = {
        "prefix": "media_files/",  # Specifies the directory to list files from
        "fields": "items(name)",  # Return only the file names
    }
    # Make the GET request to fetch the list of files
    response = requests.get(base_url, headers=headers, params=params)
    if response.status_code == 200:
        data = response.json()
        items = data.get("items", [])
        file_names = [item["name"][get_index(item["name"])+1:] for item in items]

        return file_names
    else:
        print(f"Error fetching media file names: {response.status_code} - {response.text}")
        return None
    
def get_media_file_from_firestore(file_name):
    """
    Gets a specific file from the 'media_files/' directory in the Firebase Storage bucket
    and writes it to the local 'system_data/media_files/' directory.
    """
    bucket_name = "quizzer-d70f1.firebasestorage.app"
    file_path = f"media_files/{file_name}"
    encoded_file_path = file_path.replace("/", "%2F")
    file_url = f"https://firebasestorage.googleapis.com/v0/b/{bucket_name}/o/{encoded_file_path}?alt=media"
    local_directory = "system_data/media_files/"
    local_file_path = os.path.join(local_directory, file_name)

    response = requests.get(file_url, stream=True)
    if response.status_code == 200:
        try:
            # Write the file content to the local file
            with open(local_file_path, "wb") as file:
                for chunk in response.iter_content(chunk_size=8192):
                    file.write(chunk)
            print(f"File '{file_name}' successfully downloaded to '{local_file_path}'.")
            return True
        except Exception as e:
            print(f"Error saving file '{file_name}': {e}")
            return False
    else:
        print(f"Error fetching file '{file_name}': {response.status_code} - {response.text}")
        return False
    
def write_media_file_to_firestore(file_name):
    """
    Uploads a local media file to the 'media_files/' directory in the Firebase Storage bucket.
    """
    bucket_name = "quizzer-d70f1.firebasestorage.app"
    subfolder = "media_files"
    file_path = f"{subfolder}/{file_name}"
    encoded_file_path = file_path.replace("/", "%2F")
    file_url = f"https://firebasestorage.googleapis.com/v0/b/{bucket_name}/o/{encoded_file_path}?uploadType=media"
    local_file_path = f"system_data/media_files/{file_name}"

    try:
        with open(local_file_path, "rb") as file:
            file_content = file.read()
    except FileNotFoundError:
        print(f"Error: Local file '{local_file_path}' not found.")
        return False
    except Exception as e:
        print(f"Error reading local file '{local_file_path}': {e}")
        return False
    
    headers = {"Content-Type": "application/octet-stream"}
    response = requests.post(file_url, headers=headers, data=file_content)

    if response.status_code in (200, 201):  # 201 for new files, 200 for overwrites
        print(f"File '{file_name}' successfully uploaded to Firebase Storage.")
        return True
    else:
        print(f"Error uploading file '{file_name}': {response.status_code} - {response.text}")
        return False

def submit_feedback_to_firestore(category, feedback):
    """
    Submits user feedback to the Firestore 'Feedback' collection.
    """
    print(f"Submitting feedback to Firestore: Category={category}, Feedback={feedback}")
    project_id = "quizzer-d70f1"  # Replace with your actual project ID
    api_key = "AIzaSyAWKaMkZiBzbBrcrp22-azTtnlrqqey-YA"  # Replace with your actual API key
    collection_name = "Feedback"
    url = f"https://firestore.googleapis.com/v1/projects/{project_id}/databases/(default)/documents/{collection_name}?key={api_key}"
    headers = {"Content-Type": "application/json"}
    firestore_data = {
        "fields": {
            "category": {"stringValue": category},
            "feedback": {"stringValue": feedback},
        }
    }
    response = requests.post(url, headers=headers, json=firestore_data)
    response_data = response.json()
    if response.status_code == 200:
        print(f"Feedback submitted successfully: {response_data['name']}")
        return response_data
    else:
        print(f"Failed to submit feedback: {response_data}")
        return None