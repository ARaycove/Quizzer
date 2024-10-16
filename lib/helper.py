import json
from datetime import datetime, date, timedelta
from user_profile_functions import user_profiles
import settings
import questions
import stats
import mimetypes
import os
import random
# This file contains library functions used across all modules
# also any miscellaneous functions are also stored here if not specific to a particular goal
#   for example, is_media just checks if a filetype is a media file or not
# ALL FUNCTIONS HERE ARE PUBLIC
##################################################################################################
##################################################################################################
##################################################################################################
# Read from database functions
# Had to update the helper library to check if files exist and to recreate those files if they don't exist (i.e. got deleted for some reason)
def get_instance_user_profile() -> str:
    try:
        out_file = open("instance_data/instance_user_profile.json", "r")
        instance_user_profile = json.load(out_file)
        out_file.close()
    except:
        user_profiles.verify_or_generate_user_profile() # User Default and try again
        with open("instance_data/instance_user_profile.json", "r") as f:
            instance_user_profile = json.load(f)
    return instance_user_profile

def get_module_data(module_name): # Fun Fact, this is the first get data function that'll require an argument to work:
    with open(f"modules/{module_name}/{module_name}_data.json", "r") as f:
        module_data = json.load(f)
    return module_data

def get_question_data() -> dict:
    '''
    Returns the user's questions list, if the file does not exist, returns an empty dictionary
    '''
    user_profile_name = get_instance_user_profile()
    if os.path.exists(f"user_profiles/{user_profile_name}/json_data/questions.json"):
        with open(f"user_profiles/{user_profile_name}/json_data/questions.json", "r") as f:
            questions_data = json.load(f)
        return questions_data
    elif not os.path.exists(f"user_profiles/{user_profile_name}/json_data/questions.json"):
        questions_data = {}
        return questions_data
    else:
        raise Exception(f"Unexpected error: Could not determine the existence of settings.json for USER:{user_profile_name}")
    
    
    
def get_stats_data() -> dict:
    user_profile_name = get_instance_user_profile()
    if os.path.exists(f"user_profiles/{user_profile_name}/json_data/stats.json"):
        with open(f"user_profiles/{user_profile_name}/json_data/stats.json", "r") as f:
            stats_data = json.load(f)
        return stats_data
    elif not os.path.exists(f"user_profiles/{user_profile_name}/json_data/stats.json"):
        stats.initialize_first_time_stats()
        with open(f"user_profiles/{user_profile_name}/json_data/stats.json", "r") as f:
            stats_data = json.load(f)
        return stats_data
    else:
        raise Exception(f"Unexpected error: Could not determine the existence of settings.json for USER:{user_profile_name}")



def get_settings_data() -> dict:
    user_profile_name = get_instance_user_profile()
    if os.path.exists(f"user_profiles/{user_profile_name}/json_data/settings.json"):
        with open(f"user_profiles/{user_profile_name}/json_data/settings.json") as f:
            settings_data = json.load(f)
        return settings_data
    elif not os.path.exists(f"user_profiles/{user_profile_name}/json_data/settings.json"):
        print(f"User {user_profile_name}, has no settings.json")
        print(f"Initializing settings.json")
        settings.create_first_time_settings_json()
        with open(f"user_profiles/{user_profile_name}/json_data/settings.json") as f:
            settings_data = json.load(f)
        return settings_data
    else:
        raise Exception(f"Unexpected error: Could not determine the existence of settings.json for USER:{user_profile_name}")



def get_obsidian_data() -> dict:
    user_profile_name = get_instance_user_profile()
    with open(f"user_profiles/{user_profile_name}/json_data/obsidian_data.json", "r") as f:
        obsidian_data = json.load(f)
    return obsidian_data



def get_obsidian_media_paths() -> dict:
    user_profile_name = get_instance_user_profile()
    with open(f"user_profiles/{user_profile_name}/json_data/obsidian_media_paths.json", "r") as f:
        obsidian_media_paths = json.load(f)
    return obsidian_media_paths



##################################################################################################
##################################################################################################
##################################################################################################
# Write to database functions
def update_module_data(module_data):
    '''
    feed this function the data to be written back to the modules/ folder
    each module has a module name property, so you can't fuck up and feed in the wrong module name
    Just provide the data you need to write back and this function figures out where it belongs
    '''
    module_name = module_data["module_name"]
    # Patch fix, lol
    if module_name == "Obsidian Default Module":
        module_name = "obsidian_default"
    with open(f"modules/{module_name}/{module_name}_data.json", "w+") as f:
        json.dump(module_data, f, indent=4)

def update_obsidian_data_json(data):
    user_profile_name = get_instance_user_profile()
    with open(f"user_profiles/{user_profile_name}/json_data/obsidian_data.json", "w+") as f:
        json.dump(data, f, indent=4)
        
def update_obsidian_media_paths(data):
    user_profile_name = get_instance_user_profile()
    with open(f"user_profiles/{user_profile_name}/json_data/obsidian_media_paths.json", "w+") as f:
        json.dump(data, f, indent=4)

def update_questions_json(data):
    user_profile_name = get_instance_user_profile()
    with open(f"user_profiles/{user_profile_name}/json_data/questions.json", "w") as f:
        json.dump(data, f, indent=4)
        
def update_stats_json(data):
    user_profile_name = get_instance_user_profile()
    with open(f"user_profiles/{user_profile_name}/json_data/stats.json", "w") as f:
        json.dump(data, f, indent=4)
        
def update_settings_json(data):
    user_profile_name = get_instance_user_profile()
    with open(f"user_profiles/{user_profile_name}/json_data/settings.json", "w") as f:
        json.dump(data, f, indent=4)
##################################################################################################
##################################################################################################
##################################################################################################
# Other functions

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
    sort_list = []
    for key, value in dictionary_to_shuffle.items():
        sort_list.append({key: value})
    random.shuffle(sort_list)
    return_data = {}
    for value in sort_list:
        return_data.update(value)
    return return_data

def sort_dictionary_keys(dictionary_to_sort: dict) -> dict:
    sorted_keys = sorted(dictionary_to_sort.keys())
    return {key: dictionary_to_sort[key] for key in sorted_keys}

def get_immediate_subdirectories(directory):
    """
    Returns a list of all directories immediately referenced in the given directory.
    """
    subdirectories = []
    for entry in os.listdir(directory):
        path = os.path.join(directory, entry)
        if os.path.isdir(path):
            subdirectories.append(entry)
    return subdirectories

def get_user_profiles_directory() -> str:
    return os.getcwd()+"/user_profiles"

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