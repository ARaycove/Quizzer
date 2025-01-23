# Outside Libraries
from datetime import datetime
import mimetypes
import os
import random
import sys
import shutil
def dict_size_mb(d: dict): return sys.getsizeof(d) / (1024 * 1024)

def get_user_profiles_directory() -> str:
    return "system_data/user_profiles"

def stringify_date(datetime_object):
    '''
    take a datetime object and convert to a string
    '''
    string_object = datetime_object.strftime("%Y-%m-%d %H:%M:%S")
    return string_object
def convert_to_datetime_object(string: str):
    '''
    take a valid string and turn it into a datetime object
    '''
    datetime_object = datetime.strptime(string, "%Y-%m-%d %H:%M:%S")
    return datetime_object

def is_media(file):
    mimestart = mimetypes.guess_type(file)[0]
    if mimestart != None:
        mimestart = mimestart.split('/')[0]
        if mimestart in ['audio', 'video', 'image']:
            return True
    return False

def throw_exception():
    '''
    Throws an exception, because yeah
    '''
    raise Exception("This is an exceptional message!")

def print_all_hexidecimal_characters():
    '''
    Prints out a feed of all hexidecimal characters, 50 per line
    '''
    # Why would you need this?
    var = 0 
    for i in range(5000):
        print(chr(i), end="")
        var += 1
        if var >= 50:
            print()
            var = 0

def within_twenty_four_hours(datetime_object=datetime):
    '''
    Checks whether the provided datetime is within 24 hours of now.
    Return True if within 24 hours
    Return False if not within 24 hours
    '''
    right_now = datetime.now()
    time_delta = right_now - datetime_object
    return abs(time_delta.total_seconds()) <= 24 * 3600
    
def shuffle_dictionary_keys(dictionary_to_shuffle: dict) -> dict:
    '''
    Shuffles the order of the keys in the provided dictionary
    Returns a new dictionary
    O(2n) complexity, or about 1 second per 350,000 items in the dictionary
    '''
    # print()
    # print("def helper.shuffle_dictionary_keys(dictionary_to_shuffle: dict) -> dict")
    sort_list = []
    for key, value in dictionary_to_shuffle.items():
        sort_list.append({key: value})
    random.shuffle(sort_list)
    return_data = {}
    for value in sort_list:
        return_data.update(value)
    # print(f"    Dictionary had {len(dictionary_to_shuffle)} items to shuffle")
    return return_data

def sort_dictionary_keys(dictionary_to_sort: dict) -> dict:
    # print()
    # print("def helper.sort_dictionary_keys(dictionary_to_sort: dict) -> dict")
    sorted_keys = sorted(dictionary_to_sort.keys())
    # print(f"    Dictionary had {len(dictionary_to_sort)} items to sort")
    return {key: dictionary_to_sort[key] for key in sorted_keys}

def get_immediate_subdirectories(directory):
    """
    Returns a list of all directories immediately referenced in the given directory.
    """
    subdirectories = []
    try:
        for entry in os.listdir(directory):
            path = os.path.join(directory, entry)
            if os.path.isdir(path):
                subdirectories.append(entry)
    except FileNotFoundError as e:
        subdirectories = []
    return subdirectories

def get_absolute_media_path(media_file_name, question_object):
    print(f"{media_file_name} has type {type(media_file_name)}")
    module_name = question_object["module_name"]
    # Process out double brackets
    media_file_name = str(media_file_name)
    if media_file_name.startswith("[[") and media_file_name.endswith("]]"):
        media_file_name = media_file_name[2:-2:1]
    
    current_directory = os.getcwd()    
    parent_directory = os.path.dirname(current_directory)
    media_files_directory = f"modules/{module_name}/media_files/{media_file_name}"
    file_path = media_files_directory
    return file_path

def all_zero(data):
    print("def all_zero(data)")
    status = all([x == 0 for x in data])

    print(f"    < {data} > returned status of {status}")
    return status

def detect_media_type(file_path):
    media_type, _ = mimetypes.guess_type(file_path)
    return media_type

def copy_file(file_to_copy, location):
    print(f"def copy_file(file_to_move, location)")
    try:
        shutil.copy(file_to_copy, location)
        print(f"    File '{file_to_copy}' copied successfully to '{location}'.")
    except shutil.Error as e:
        print(f"    Error when copying file {e}")