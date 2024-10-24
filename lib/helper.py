import json
from datetime import datetime, date, timedelta
from user_profile_functions import user_profiles
from settings_functions import settings
from question_functions import questions
from stats_functions import stats
from module_functions import modules, new_module_defines
from initialization_functions import initialize
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
############################################
# Master questions list
# All question objects are stored once in this json file
# Distributed to every user, contains the entirety of the Quizzer Directory
def get_question_object_data() -> dict:
    try:
        
        with open("system_data/question_object_data.json", "r") as f:
            question_object_data = json.load(f)
        print("Question Object Data exists:")
        return question_object_data
    except:
        # We fail to open, which means the question_object_data does not exist
        # Create the question_object_data.json
        print("Question Object Data does not exist, initializing question_object_data.json")
        initialize.initialize_question_object_data_json()
        with open("system_data/question_object_data.json", "r") as f:
            question_object_data = json.load(f)
        return question_object_data

def update_question_object_data(question_object_data: dict) -> None:
    '''
    Updates the master question_object_data with the updated information
    '''
    try:
        # Place lock on file
        # Run in seperate thread?
        with open("system_data/question_object_data.json", "w+") as f:
            json.dump(question_object_data, f, indent=4)
        # Indices that should be recalculated when question_object_data changes
        build_module_data()
        build_subject_data()
        build_concept_data()

        print("Question Object Data exists:")
    except:
        # We fail to open, which means the question_object_data does not exist
        # Create the question_object_data.json
        print("Question Object Data does not exist, initializing question_object_data.json")
        initialize.initialize_question_object_data_json()
        with open("system_data/question_object_data.json", "w+") as f:
            json.dump(question_object_data, f, indent=4)

def add_question_object(question_object: dict) -> None:
    '''
    Gets the question_object_data.json file
    adds the provided question_object to question_object_data
    Updates the question_object_data.json file
    '''
    print("Oh Yeah")
    question_object_data = get_question_object_data()
    unique_id = question_object["id"]
    write_data = {unique_id: question_object}
    question_object_data.update(write_data)
    update_question_object_data(question_object_data)
    

############################################
# Module data
## Modules contain a list of question id's not the question objects themselves
## returned data is a single json file
## Designed so that this file can be shared
## Distributed to every user, contains the entirety of the Quizzer Database
## Allows offline browsing of community modules
def calculate_num_questions_in_module(module_name: str, all_module_data) -> int:
    num_questions = len(all_module_data[module_name]["questions"])
    return num_questions
def build_module_data() -> dict:
    '''
    Builds the module_data.json based on the master question_object_data file
    Should be called only when a change is made to question_object_data
    '''
    all_module_data = {}
    # Build module data based on question object data
    question_object_data = get_question_object_data()
    for unique_id, question_object in question_object_data.items():
        # Each key is the module_name, followed by a dictionary containing all the data of that module
        if questions.verify_question_object(question_object) == False:
            continue #handle exception where question_object does not have a module_name
        module_name = question_object["module_name"]
        # Check if we've already added that module name to all_module_data:
        if module_name not in all_module_data: 
            module_name_data = new_module_defines.defines_initial_module_data(module_name)
            # Ensure we add the module_name key before editing it (we can't edit something that doesn't exist)
            all_module_data[module_name] = module_name_data
        else:
            module_name_data = all_module_data[module_name]
        # Add question object id to module_data["questions"] field
        module_name_data["questions"].append(question_object["id"])
        module_name_data["num_questions"] = calculate_num_questions_in_module(module_name, all_module_data)
        all_module_data[module_name].update(module_name_data)

    with open("system_data/module_data.json", "w+") as f:
        json.dump(all_module_data, f, indent=4)
    # Write to system_data
    return all_module_data    

def get_all_module_data() -> dict: # Fun Fact, this is the first get data function that'll require an argument to work:
    try:
        with open(f"system_data/module_data.json", "r") as f:
            all_module_data = json.load(f)
        print("module_data exists")
        for module_name in all_module_data:
            all_module_data[module_name]["num_questions"] = calculate_num_questions_in_module(module_name, all_module_data)
        return all_module_data
    except FileNotFoundError as e:
        print(e, "initializing module_data")
        all_module_data = build_module_data()
        with open("system_data/module_data.json", "w+") as f:
            json.dump(all_module_data, f, indent=4)
        return all_module_data
############################################
# Subject Data
# Dictionary, where each key is a subject, data is a nested dictionary relating to that subject
# Each subject references question objects that contain that subject
# Each subject or "field of study" will reference:
# - question object id's that contain that subject
# - Number of times subject is mentioned by question objects (get sum of id's for each field)
# - FIXME Related subjects (i.e. biology would reference anatomy and physiology)
# - FIXME Related concepts (i.e. biology would reference every term under the umbrella of biology, including terms belonging to anatomy: anatomy would only reference terms related to anatomy and any terms relating to subjects that fall under anatomy "niche subjects")
def build_subject_data():
    subject_data = {}
    question_object_data = get_question_object_data()
    for unique_id, question_object in question_object_data.items():
        for subject in question_object["subject"]:
            if subject not in subject_data:
                # initialize subject as a dictionary
                subject_data[subject] = {}
                # initialize questions field as a list
                subject_data[subject]["questions"] = []
                # append the id for that question to the list
                subject_data[subject]["questions"].append(unique_id)
            else:
                subject_data[subject]["questions"].append(unique_id)
    # Less operations to run a second for loop for this calculation
    for subject in subject_data:
        subject_data[subject]["num_questions"] = len(subject_data[subject]["questions"])
    with open("system_data/subject_data.json", "w+") as f:
        json.dump(subject_data, f, indent=4)
    return subject_data

def get_subject_data() -> dict:
    try:
        with open("system_data/subject_data.json", "r") as f:
            subject_data = json.load(f)
        return subject_data
    except FileNotFoundError as e:
        print(e, "Now initializing subject_data.json")
        subject_data = build_subject_data()
        return subject_data

############################################
# concept_data
# Each Concept or Term will contain:
# - question object id's that reference that concept
# - Number of times that concept is mentioned by the resulting question_id's
# - FIXME Related concepts and terms
# - FIXME Related subjects and field of study (Should only be one, but could be multiple, such as the term "memory" relates to both computer science and neuroscience and biology)
# - FIXME A description string
# - FIXME A list of sources that mention this concept
def build_concept_data() -> dict:
    concept_data = {}
    question_object_data = get_question_object_data()
    for unique_id, question_object in question_object_data.items():
        if question_object["related"] == None:
            continue
        for concept in question_object["related"]:
            if concept not in concept_data:
                concept_data[concept] = {}
                concept_data[concept]["questions"] = []
                concept_data[concept]["questions"].append(unique_id)
            else:
                concept_data[concept]["questions"].append(unique_id)
    
    for concept in concept_data:
        concept_data[concept]["num_questions"] = len(concept_data[concept]["questions"])
    
    with open("system_data/concept_data.json", "w+") as f:
        json.dump(concept_data, f, indent=4)
    return concept_data

def get_concept_data() -> dict:
    try:
        with open("system_data/concept_data.json", "r") as f:
            concept_data = json.load(f)
        return concept_data
    except FileNotFoundError as e:
        print(e, "Now initializing concept_data.json")
        concept_data = build_concept_data()
        return concept_data


############################################
# user_data indices
# System will contain a list of user_profiles
# Each user profile json file will contain:
# - uuid
# - user profile data
# - settings
# - stats
# - all questions (is a list of id's)
# - eligible questions
# - ineligible questions
# - modules (is a list of modules that were at any point activated by the user)
def get_user_profiles_directory() -> str:
    return "system_data/user_profiles"

def get_user_list():
    '''
    Updates the current list of users to provide to the drop down menu
    '''
    current_user_list = get_immediate_subdirectories(get_user_profiles_directory())
    return current_user_list

def get_all_user_data():
    all_user_data = {}
    user_list = get_user_list()
    if user_list == []:
        return all_user_data
    for user in user_list:
        user_profile_data = get_user_data(user)
        user_uuid = user["uuid"]
    #FIXME gather all data, this will be a server side function to get all the users across all instances

def get_user_data(user_profile_name: str) -> dict:
    # data in the format of user_profile_name_data.json
    # system_data/user_profiles/karibar/karibar_data.json
    user_profile_name = user_profile_name.lower()
    try:
        with open(f"system_data/user_profiles/{user_profile_name}/{user_profile_name}_data.json", "r") as f:
            user_profile_data = json.load(f)
        return user_profile_data
    except FileNotFoundError as e:
        print(e, f"Generating user_profile: {user_profile_name}")
        question_object_data = get_question_object_data()
        user_profile_data = user_profiles.add_new_user(user_profile_name, question_object_data)
        return user_profile_data

def update_user_question_stats(user_profile_data: dict) -> None:
    for question in user_profile_data["questions"]:
        pass

def update_user_profile(user_profile_data: dict) -> None:
    user_name = user_profile_data["user_name"]
    with open(f"system_data/user_profiles/{user_name}/{user_name}_data.json", "w+") as f:
        json.dump(user_profile_data, f, indent=4)

# From within the interface, the user can browse all available modules defined in system_data/module_data.json
# So interface should fire up only based on the initial user_profile_data
############################################
# Miscellaneous / Old
##################################################################################################
##################################################################################################
##################################################################################################
# Write to database functions
def update_module_data(module_data: dict) -> None:
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