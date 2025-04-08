# All functions relating to the generation, updates, and fetching of system data goes in this file
# Dev Modules
from lib import helper
import system_data_user_stats
import system_data_question_stats # Any function that works directly with the user question stats, scoring metrics related to the question object
# External Libs
import json
import os
import uuid
from datetime import datetime, timedelta, date
import math
import random
import firestore_db
import matplotlib.pyplot as plt
# Any Function that does not call another function (besides external libs)
def build_first_time_stats_data(user_profile_data: dict = None) -> dict:#Private Function
    '''
    Initial stats for new users
    '''
    stats_data = {}
    stats_data["questions_answered_by_date"] = {f"{date.today()}": 0}
    stats_data["total_questions_answered"] = 0
    stats_data["average_questions_per_day"] = 0
    return stats_data

def verify_system_data_directory():
    if not os.path.exists("system_data"):
        os.makedirs("system_data")

def verify_user_profiles_directory(user_name) -> None:
    '''
    Ensures the os path for the user_profiles exists
    '''
    if not os.path.exists(f"system_data/user_profiles"):
        os.makedirs("system_data/user_profiles")
    if not os.path.exists(f"system_data/user_profiles/{user_name}"):
        os.makedirs(f"system_data/user_profiles/{user_name}")

def verify_user_dir_doesnt_exist(user_name) -> bool:
    '''
    returns True if the user_profile already exists
    returns False if the user_profile doesn't exist
    '''
    if os.path.exists(f"system_data/user_profiles/{user_name}/{user_name}_data.json") == True:
        # print(f"Profile {user_name} already exists")
        return True
    else:
        return False

def generate_unique_id_for_user() -> uuid:
    got_unique_id = False

    while (got_unique_id == False):
        unique_user_id = uuid.uuid4()
        #FIXME do check to ensure id generated is actually unique
        current_user_id_list = []
        if unique_user_id in current_user_id_list:
            pass
        else:
            got_unique_id = True

    return unique_user_id

def update_user_profile(user_profile_data: dict) -> None:
    user_name = user_profile_data["user_name"]
    with open(f"system_data/user_profiles/{user_name}/{user_name}_data.json", "w+") as f:
        json.dump(user_profile_data, f, indent=4)

def calculate_question_id(question_object: dict, user_uuid) -> dict: #Private Function
    '''
    Deprecated, does nothing: is a function stub
    question id is based on the users questions.json
    question id does not exist in the "clean" variant of the question object
    This method prevents duplicate ids, since the id will be determined once the once the user "collects" a given question so will never interfere with others version of the id
    '''
    # if the question_object has already gotten an id then we don't need to recalculate it:
    if question_object.get("id") != None:
        return question_object

    # The always unique id is the time in which the id was created alongside the user's uuid who made it, this method is gauranteed to always be unique except if a single user is able to create two objects in the space in time
    current_time = str(datetime.now())
    unique_id = current_time + "_" + user_uuid
    question_object["id"] = unique_id

    return question_object
############################################################################
############################################################################
############################################################################
############################################################################
# Server side - question_object_data
# Functions relating to question objects
############################################################################
# Individual property Updates
def determine_related_concepts_for_question(question_object=dict) -> list:
    '''
    Use AI to determine what concepts are referred to in the question
    '''
    return None

def determine_individual_subjects_for_question(question_object=dict) -> list:
    '''
    Use AI to determine what subjects and fields are referred to in the question
    '''
    return ["miscellaneous"]

def determine_question_subjects(question_object:dict) -> dict:
    '''
    Logic is not implemented, only sets the subject value to miscellaneous if no subject was entered
    '''
    if question_object.get("subject") == None:
        question_object["subject"] = determine_individual_subjects_for_question(question_object)
        return question_object
    else:
        return question_object

def determine_related_concepts(question_object: dict) -> dict:
    '''
    Logic is not implemented, only sets the related value to None if no related concepts were entered
    '''
    if question_object.get("related") == None:
        question_object["related"] = determine_individual_subjects_for_question(question_object)
        return question_object
    else:
        return question_object

############################################################################
def verify_question_object(question_object: dict) -> bool:
    '''
    Returns True if the question object has all minimum required properties
    Returns False if the question object is missing required properties
    '''
    # qf = question field
    # af = answer field

    #Question treated as invalid by default
    qf_is_valid = False
    af_is_valid = False
    is_valid = False
    if question_object == None:
        return is_valid
    # Validate question_object has a module_name attached NOTE Every question_object must belong to a module
    if question_object["module_name"] == None:
        return is_valid
    if question_object["module_name"] == "":
        return is_valid
    
    
    # Validate question field
    if question_object.get("question_text") != None:
        qf_is_valid = True
    elif question_object.get("question_image") != None:
        qf_is_valid = True
    elif question_object.get("question_audio") != None:
        qf_is_valid = True
    elif question_object.get("question_video") != None:
        qf_is_valid = True

    # Validate Answer Field
    if question_object.get("answer_text") != None:
        af_is_valid = True
    elif question_object.get("answer_image") != None:
        af_is_valid = True
    elif question_object.get("answer_audio") != None:
        af_is_valid = True
    elif question_object.get("answer_video") != None:
        af_is_valid = True
    
    # Question objects need both a question and an answer to the question to be valid
    # NOTE This is because questions without answers are not entirely helpful
    # NOTE However philisophical questions don't have defined answers, however such questions should indicate that in the answer field
    if qf_is_valid == True and af_is_valid:
        is_valid = True
        return is_valid
    else:
        return is_valid
    
def verify_new_question(
        user_profile_data: dict, # We need the uuid to mark the author of the question object, prevent users from modifying other people's questions
        id: str = None,
        primary_subject: str = "miscellaneous",
        subject: list = ["miscellaneous"],
        related: list = None,
        question_text = None, question_image = None, question_audio = None, question_video = None,
        answer_text = None, answer_image = None, answer_audio = None, answer_video = None,
        module_name: str = None) -> dict:
    '''
    receives data as input and outputs a question object with all fields not defined set to None
    Used in conjunction with the add_new_question_object function
    Returns a question_object if it's valid
    Returns None if the question_object is not valid
    '''
    question_object = {}
    # Make exception for "Quizzer Tutorial Module", all other questions running through this function will get assigned a question_id proper
    if module_name != "quizzer tutorial":
        user_uuid = user_profile_data["uuid"]
        question_object = calculate_question_id(question_object, user_uuid)
    else:
        question_object["id"] = id
    question_object["primary_subject"] = primary_subject
    question_object["subject"] = subject
    question_object["related"] = related
    question_object["question_text"] = question_text
    question_object["question_audio"] = question_audio
    question_object["question_image"] = question_image
    question_object["question_video"] = question_video
    question_object["answer_text"] = answer_text
    question_object["answer_audio"] = answer_audio
    question_object["answer_image"] = answer_image
    question_object["answer_video"] = answer_video
    question_object["module_name"] = module_name
    # question object is now constructed
    # question object needs to be validated
    is_valid = verify_question_object(question_object)
    if is_valid == False:
        return None
    return question_object

def generate_quizzer_tutorial_question_objects()-> list:
    '''
    returns a Hardcoded list of question objects associated with the Quizzer Tutorial
    designed to be used with the helper.get_question_object_data() function
    is called in case question_object_data.json doesn't exist
    '''
    # FIXME Deprecated
    pass
    # questions_data = {}
    # questions_list = []
    # question_one = (verify_new_question(
    #     id = "tutorial_question_one",
    #     question_text = "Welcome to Quizzer: Click the question to flip over to the answer",
    #     answer_text = "Now press the checkmark if you get a question correct, or press the cancel circle if you got it wrong. Quizzer is self-scored, and relies on you being honest with yourself!",
    #     module_name = "quizzer tutorial"
    # ))

    # questions_list.extend([question_one])

    # return questions_list

def initialize_question_object_data_json():
    '''
    Creates the template for which user_profiles can initialize their question list
    '''
    pass #FIXME deprecated
    # question_object_data = {}
    # quizzer_tutorial_questions = []
    # for question_object in quizzer_tutorial_questions:
    #     unique_id = question_object["id"]
    #     write_data = {unique_id: question_object}
    # question_object_data.update(write_data)
    # verify_system_data_directory()
    # with open("system_data/question_object_data.json", "w+") as f:
    #     json.dump(question_object_data, f)

def get_question_object_data() -> dict:
    try:
        with open("system_data/question_object_data.json", "r") as f:
            question_object_data = json.load(f)
        # print("Question Object Data exists:")
        return question_object_data
    except FileNotFoundError:
        firestore_db.get_question_object_data_from_firestore()
        with open("system_data/question_object_data.json", "r") as f:
            question_object_data = json.load(f)
        # print("Question Object Data exists:")
        return question_object_data

def update_question_object_data(question_object_data: dict) -> None:
    '''
    Updates the master question_object_data with the updated information
    '''
    print("I have been called")
    for unique_id, question_object in question_object_data.items():
        try:
            if question_object_data[unique_id]["subject"] != None:
                question_object_data[unique_id]["subject"] = [i.lower() for i in question_object_data[unique_id]["subject"]]
        except TypeError as e:
            print(e)
            print(unique_id)
            print(question_object)
        try:    
            question_object_data[unique_id]["module_name"]  = question_object_data[unique_id]["module_name"].lower()
        except TypeError:
            pass
    if question_object_data == None or question_object_data == {}:
        print("BAZINGA, object is NONE")
        return None
    
    try:
        # Place lock on file
        # Run in seperate thread?
        with open("system_data/question_object_data.json", "w+") as f:
            json.dump(question_object_data, f, indent=4)
        # Indices that should be recalculated when question_object_data changes
        build_module_data()
        build_subject_data()
        build_concept_data()

        # print("Question Object Data exists:")
    except:
        # We fail to open, which means the question_object_data does not exist
        # Create the question_object_data.json
        # print("Question Object Data does not exist, initializing question_object_data.json")
        initialize_question_object_data_json()
        with open("system_data/question_object_data.json", "w+") as f:
            json.dump(question_object_data, f, indent=4)

############################################################################
############################################################################
############################################################################
############################################################################
############################################################################
# Server side - Module System
def update_module_all_subjects_property(module_data):
    subject_list = []
    for unique_id, question_object in module_data["questions"].items():
        for subject in question_object["subject"]:
            if subject not in subject_list:
                subject_list.append(subject)
        module_data["all_subjects"] = subject_list
    return module_data

def update_module_all_concepts_property(module_data):
    concepts_covered = {} # {concept: num_times_mentioned}
    for unique_id, question_object in module_data["questions"].items():
        if question_object.get("related") != None: # Catch TypeError if question_object is missing the "related" field
            for concept in question_object["related"]:
                # Parse out double brackets
                if concept.startswith("[[") and concept.endswith("]]"):
                    concept = concept[2:-2]
                if concept not in concepts_covered:
                    concepts_covered[concept] = 1
                else:
                    concepts_covered[concept] += 1
        module_data["concepts_covered"] = concepts_covered
    return module_data

def update_module_primary_subject_property(module_data):
    subject_counts = {}
    for unique_id, question_object in module_data["questions"].items():
        for subject in question_object["subject"]:
            if subject not in subject_counts:
                subject_counts[subject] = 1
            else:
                subject_counts[subject] += 1
    # We got an error because one of the modules had an empty questions list,
    # To handle for this we will check if the questions field has data or is still an empty dictionary
    # If it is an empty dictionary, we will immediately return module_data, otherwise we'll be able to determine a primary subject
    if module_data["questions"] == {}:
        return module_data
    module_data["primary_subject"] = str(max(subject_counts, key=subject_counts.get)).title()
    return module_data

def calculate_num_questions_in_module(module_name: str, all_module_data) -> int:
    num_questions = len(all_module_data[module_name]["questions"])
    return num_questions

def defines_initial_module_data(module_name=str) -> dict:
    '''
    This function returns a dictionary containing default data so that all new modules are uniform
    '''
    initial_module_data = {}
    # Series of initial properties
    initial_module_data["module_name"] = module_name
    initial_module_data["description"] = "No Description Provided"
    initial_module_data["author"] = ""
    initial_module_data["is_a_quizzer_module"] = True #
    initial_module_data["activated"] = True
    initial_module_data["primary_subject"] = ""
    initial_module_data["all_subjects"] = []
    initial_module_data["concepts_covered"] = []
    initial_module_data["questions"] = []
    # This is a return statement 
    # :'( <--- this is a crying face in case you didn't get the joke.
    return initial_module_data

def build_module_data() -> dict:
    '''
    Builds the module_data.json based on the master question_object_data file
    Should be called only when a change is made to question_object_data
    '''
    print("I am rebuilding the module_data")
    all_module_data = {}
    # Build module data based on question object data
    question_object_data = get_question_object_data()
    for unique_id, question_object in question_object_data.items():
        # Each key is the module_name, followed by a dictionary containing all the data of that module
        if verify_question_object(question_object) == False:
            continue #handle exception where question_object does not have a module_name
        module_name = question_object["module_name"].lower()
        # Check if we've already added that module name to all_module_data:
        if module_name not in all_module_data: 
            module_name_data = defines_initial_module_data(module_name)
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
        # print("module_data exists")
        for module_name in all_module_data:
            all_module_data[module_name]["num_questions"] = calculate_num_questions_in_module(module_name, all_module_data)
        return all_module_data
    except FileNotFoundError as e:
        # print(e, "initializing module_data")
        all_module_data = build_module_data()
        with open("system_data/module_data.json", "w+") as f:
            json.dump(all_module_data, f, indent=4)
        return all_module_data
############################################################################
############################################################################
############################################################################
############################################################################
############################################################################
# Server side - Subject Database
def build_subject_data():
    import json
    subject_data = {}
    question_object_data = get_question_object_data()
    for unique_id, question_object in question_object_data.items():
        if question_object == None:
            continue #handle exception where question_object is invalid
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
    import json
    try:
        with open("system_data/subject_data.json", "r") as f:
            subject_data = json.load(f)
        return subject_data
    except FileNotFoundError as e:
        # print(e, "Now initializing subject_data.json")
        subject_data = build_subject_data()
        return subject_data

############################################################################
############################################################################
############################################################################
############################################################################
############################################################################
# Server side - Concept Database
def build_concept_data() -> dict:
    import json
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
    import json
    try:
        with open("system_data/concept_data.json", "r") as f:
            concept_data = json.load(f)
        return concept_data
    except FileNotFoundError as e:
        # print(e, "Now initializing concept_data.json")
        concept_data = build_concept_data()
        return concept_data

############################################################################
############################################################################
############################################################################
############################################################################
############################################################################
# Server side - User profile system
def get_user_list():
    '''
    Updates the current list of users to provide to the drop down menu
    '''
    current_user_list = helper.get_immediate_subdirectories(helper.get_user_profiles_directory())
    return current_user_list

def get_all_user_data():
    all_user_data = {}
    user_list = get_user_list()
    if user_list == []:
        return all_user_data
    for user in user_list:
        user_profile_data = get_user_data(user)
        user_uuid = user["uuid"]



def generate_first_time_questions_dictionary() -> dict:
    '''
    Every new user gets the quizzer tutorial as a module added into their profile  
    Called by add_new_user(user_name)  
    '''
    # Initialize an empty dict 
    questions_data = {}
    questions_data["unsorted"] = {}                         # Newly added questions go here
    questions_data["deactivated"] = {}                      # Questions with deactivated modules go here
    questions_data["reserve_bank"] = {}                     # Questions not circulating currently go here -> will get checked by add questions to circulation
    questions_data["in_circulation_not_eligible"] = {}      # Questions placed into circulation but not eligible to be answered go here -> subdivided further by due date to minimize unneccessary operations
    questions_data["in_circulation_is_eligible"] = {}       # Questions placed into circulation AND are eligible to be answered go here -> will be displayed to the user immediately
    # Load in the quizzer_tutorial_module 
    module_data = get_all_module_data()
    # Build first question set based on the questions in the Quizzer Tutorial Module 
    quizzer_tutorial = module_data["quizzer tutorial"]
    for unique_id in quizzer_tutorial["questions"]:
        write_data = {unique_id: {}}
        questions_data["unsorted"].update(write_data) #NOTE tutorial questions will immediately go into the unsorted "pile"
    # Send the data back to the add_new_user(user_name) function which calls this 
    return questions_data

def build_subject_settings(user_profile_data: dict, question_object_data) -> dict: #Private Function
    '''
    Builds or rebuilds the subject settings for the specific user
    '''
    # print("def settings.build_subject_settings(user_profile_data: dict, question_object_data) -> dict")
    try:
        subject_settings            = user_profile_data["settings"]["subject_settings"]
    except KeyError:
        subject_settings            = {}
    total_all_list              = []
    num_questions_in_circ_list  = []
    total_activated_list        = []
    all_subjects_set            = set([])

    # serves as a template for later
    initial_subject_setting = {}
    initial_subject_setting["interest_level"] = 10
    initial_subject_setting["priority"] = 9
    initial_subject_setting["total_questions"] = 0
    initial_subject_setting["num_questions_in_circulation"] = 0
    initial_subject_setting["total_activated_questions"] = 0
    # print(initial_subject_setting)
    # Iterate over every question id contained in the user's 
    all_user_questions = {}
    for pile_name, pile in user_profile_data["questions"].items():
        all_user_questions.update(pile)

    # Talley up the the three values we need
    for question_id, user_question_data in all_user_questions.items():
        question_object = question_object_data[question_id].copy()
        module_name = question_object["module_name"]
        if question_object["subject"] == None:
            question_object["subject"] = ["miscellaneous"]
            question_object_data[question_id]["subject"] = ["miscellaneous"]
        for subject_val in question_object["subject"]:
            total_all_list.append(subject_val)
            all_subjects_set.add(subject_val)
            if question_id in user_profile_data["questions"]["in_circulation_not_eligible"] or question_id in user_profile_data["questions"]["in_circulation_is_eligible"]:
                num_questions_in_circ_list.append(subject_val)
            try:
                if user_profile_data["settings"]["module_settings"]["module_status"][module_name] == True:
                    total_activated_list.append(subject_val)
            except KeyError: # Likely due to first time user
                pass

    for sub in all_subjects_set:
        if sub not in subject_settings:
            subject_settings[sub] = {}
            subject_settings[sub]["interest_level"]             = 10
            subject_settings[sub]["priority"]                   = 9
            subject_settings[sub]["total_questions"]                 = 0
            subject_settings[sub]["num_questions_in_circulation"]    = 0
            subject_settings[sub]["total_activated_questions"]       = 0
        subject_settings[sub]["total_questions"]                = total_all_list.count(sub)
        subject_settings[sub]["num_questions_in_circulation"]   = num_questions_in_circ_list.count(sub)
        subject_settings[sub]["total_activated_questions"]      = total_activated_list.count(sub)
        # print("    Determining if subjects has available questions")
        if subject_settings[sub]["total_activated_questions"] == subject_settings[sub]["num_questions_in_circulation"]:
            subject_settings[sub]["has_available_questions"] = False
        else:
            subject_settings[sub]["has_available_questions"] = True
    
        # print(f"{subject.title():25} has {in_circulation_count:5}/{total_count:<5} currently in circulation")
    subject_settings = helper.sort_dictionary_keys(subject_settings)
    return subject_settings

def build_module_settings(user_profile_data: dict, question_object_data: dict) -> dict:
    # First check if we've already built module_settings for this user, since we will reuse this function for subsequent
    # print()
    # print("def settings.build_module_settings(user_profile_data:dict, question_object_data: dict) -> dict") 
    if user_profile_data.get("module_settings") != None:
        module_settings = user_profile_data["module_settings"]
    else:
        module_settings = {}
        module_settings["is_module_active_by_default"] = True
        module_settings["module_status"] = {} # {module_name: bool}
    default_status = module_settings["is_module_active_by_default"]
    # Iterate over every question id and add the module_name to module_status with the default status of ["is_module_active_by_default"]
    for pile_name, pile in user_profile_data["questions"].items():
        if pile_name != "unsorted": #Only scan through newly added questions
            continue
        for unique_id, question_object in pile.items():
            module_name = question_object_data[unique_id]["module_name"].lower()
            # Only add to list, never delete from it
            if module_name.lower() not in module_settings["module_status"].keys():
                module_settings["module_status"][module_name] = default_status
    
    return module_settings

def build_first_time_settings_data(user_profile_data, question_object_data) -> dict:
    settings_data = {}
    settings_data["quiz_length"] = 25
    settings_data["time_between_revisions"] = 1.4
    settings_data["due_date_sensitivity"] = 12
    settings_data["vault_path"] = ["enter/path/to/obsidian/vault"]
    settings_data["desired_daily_questions"] = 50
    user_profile_data["settings"] = settings_data
    settings_data["subject_settings"] = build_subject_settings(user_profile_data, question_object_data)
    settings_data["module_settings"] = build_module_settings(user_profile_data, question_object_data)
    return settings_data

def generate_first_time_settings_dictionary(user_profile_data:dict, question_object_data: dict) -> dict:
    settings_data = {} 
    settings_data = build_first_time_settings_data(user_profile_data, question_object_data)
    return settings_data

def generate_first_time_stats_dictionary(user_profile_data:dict) -> dict:
    stats_data = {}
    stats_data = build_first_time_stats_data(user_profile_data)
    return stats_data
def sort_individual_question(question_id, question_object, current_location, user_profile_data):
    # Define sorting criteria
    is_module_active    = question_object["is_module_active"]
    is_circulating      = question_object["in_circulation"]
    is_eligible         = question_object["is_eligible"]
    question_to_write   = {question_id: question_object}
    # We will not touch the deactivated pile, the only time this pile gets touched is if the user decides to activate a module
    # We will not touch the reserve bank pile either, the only time the reserve bank is touched is by the function that attempts to place questions into circulation

    # If the module that the question belongs to is not active immediately put it in the deactivated pile, regardless of its current location
    if is_module_active == False:
        print(f"    Moving question {question_id} to deactivated pile")
        del user_profile_data["questions"][current_location][question_id]
        user_profile_data["questions"]["deactivated"].update(question_to_write)
        return user_profile_data
    
    # For non circulating questions whose modules are active, move to reserve bank
    if is_circulating == False:
        print(f"    Moving question {question_id} to reserve_bank")
        del user_profile_data["questions"][current_location][question_id]
        user_profile_data["questions"]["reserve_bank"].update(question_to_write)
        return user_profile_data
    
    # If the question is currently in the unsorted pile, it may go to either the deactivated pile OR the reserve_bank pile
    #   Since we've already checked if the question goes into the deactivated pile, we need only put it in the reserve bank
    if current_location == "unsorted": # assume module is active, if wasn't then we would have hit the condition on 642
        print(f"    Moving question {question_id} to reserve_bank")
        del user_profile_data["questions"][current_location][question_id]
        user_profile_data["questions"]["reserve_bank"].update(question_to_write)
        return user_profile_data
    
    # if in the circulating and not eligible pile, but the question is marked as eligible, move it to the eligible pile
    if current_location == "in_circulation_not_eligible" and is_eligible == True:
        print(f"    Moving question {question_id} to eligible pile")
        del user_profile_data["questions"][current_location][question_id]
        user_profile_data["questions"]["in_circulation_is_eligible"].update(question_to_write)
        return user_profile_data
    
    # if in the is eligible pile, but the question is marked as not eligible, move it to the not eligible pile
    if current_location == "in_circulation_is_eligible" and is_eligible == False:
        del user_profile_data["questions"][current_location][question_id]
        print(f"    Moving question {question_id} to not eligible pile")
        user_profile_data["questions"]["in_circulation_not_eligible"].update(question_to_write)
        return user_profile_data

    return user_profile_data
def sort_questions(user_profile_data: dict, question_object_data: dict):
    '''
    Goes through any questions in the unsorted pile, updates them, then moves them to an appropriate "pile"
    # Questions will be sorted into multiple "piles"
    # Piles:
    # Unsorted: the default place where newly added questions will be put
    # Deactivated:                      If the question's module is deactivated we should place the entry here so we can avoid unneccessary operations
    # NOTE This pile will get scanned whenever module_status changes #FIXME
    # in_circulation - not eligible:    If the question has been placed into circulation but is not currently eligible place it in this pile
    # NOTE circulating but non-eligible questions will be stored under a key by the name of str(datetime.today())
    # in_circulation - is eligible:     If the question has been placed into circulation and is also eligible then place it here, sorted by due_date (where due_date is the key, we need only check items that are within or before today's date) delete empty keys
    '''
    # when the program starts a function will decide what to put into circulation, that function will put things into circulation, update properties for those questions and then recall this function to sort them out before sending back to user
    
    # We will first do a check against the module questions, if a question is referenced in a module, but does not exist in the user profile, then we will add that question to the user profile
    all_module_data = get_all_module_data()
    user_profile_data = verify_module_in_user_profile(user_profile_data, all_module_data)
    user_profile_data_copy = user_profile_data.copy()
    for pile_name, pile in user_profile_data_copy["questions"].items():
        if pile_name != "deactivated" and pile_name != "reserve_bank":
            print(f"Now iterating over {pile_name}")
            for question_id, question_object in pile.copy().items():
                # activate module function handles deactivated questions, update_circulation handles reserve bank questions
                
                    # update the statistics for that question
                    question_object = update_user_question_stats(question_object, question_id, user_profile_data, question_object_data)
                    user_profile_data = sort_individual_question(question_id, question_object, pile_name, user_profile_data)
    #####################################################################################
    questions_data = user_profile_data["questions"]
    return questions_data

############################################################################################################################################
############################################################################################################################################
############################################################################################################################################
############################################################################################################################################
############################################################################################################################################
# Slowly going to sort this file out so that only functions directly used by the main program will be in system_data.py
# This also includes function modules directly used by the main program such as generate_quiz.py
# All other functions will be split out into highly specific modules (All the functions required by the "master" functions)
def update_user_question_stats(question_object: dict, unique_id, user_profile_data: dict, question_object_data: dict) -> dict:
    # print("def update_user_question_stats(question_object: dict, unique_id, user_profile_data: dict, question_object_data: dict) -> dict")
    settings_data = user_profile_data["settings"]
    question_object = system_data_question_stats.initialize_revision_streak_property(question_object)
    question_object = system_data_question_stats.initialize_last_revised_property(question_object)
    question_object = system_data_question_stats.initialize_next_revision_due_property(question_object)
    question_object = system_data_question_stats.initialize_in_circulation_property(question_object, settings_data)
    question_object = system_data_question_stats.initialize_time_between_revisions_property(question_object, settings_data)
    question_object = system_data_question_stats.calculate_average_shown(question_object)
    question_object = system_data_question_stats.determine_eligibility_of_question_object(question_object, settings_data)
    question_object = system_data_question_stats.update_is_module_active_property(question_object, unique_id, user_profile_data, question_object_data)
    if type(question_object) != type({}):
        # print(f"Question Object has type {type(question_object)}")
        raise Exception("Question Object is not a dictionary, one of the properties is returning the wrong object")
    return question_object

def add_new_user(user_name: str, question_object_data) -> dict: #Public Function
    '''
    Adds a new user to the local system, returns the default data
    '''
    if user_name == "":
        return None
    user_name = user_name.lower()
    # All data for the user is stored in a master dictionary
    does_exist = verify_user_dir_doesnt_exist(user_name)
    verify_user_profiles_directory(user_name)
    user_profile_data = {}
    if does_exist == False:
        # print(f"Creating user profile with name {user_name}")
        user_profile_data["uuid"] = str(generate_unique_id_for_user())
        user_profile_data["user_name"] = user_name
        # These only need to return a predefined dictionary, so nothing is fed into them
        user_profile_data["questions"] = generate_first_time_questions_dictionary()
        user_profile_data["settings"] = generate_first_time_settings_dictionary(user_profile_data, question_object_data)
        user_profile_data["stats"] = generate_first_time_stats_dictionary(user_profile_data)
        for pile_name, pile in user_profile_data["questions"].items():
            for unique_id, question_object in pile.items():
                question_object = update_user_question_stats(question_object, unique_id, user_profile_data, question_object_data)
        update_user_profile(user_profile_data)
    firestore_db.write_user_profile_to_firestore(user_name)
    return user_profile_data

def get_user_data(user_profile_name: str) -> dict:
    # data in the format of user_profile_name_data.json
    # system_data/user_profiles/karibar/karibar_data.json
    user_profile_name = user_profile_name.lower()
    try:
        with open(f"system_data/user_profiles/{user_profile_name}/{user_profile_name}_data.json", "r") as f:
            user_profile_data = json.load(f)
        return user_profile_data
    except FileNotFoundError as e:
        user_profile_data = firestore_db.get_user_profile_from_firestore(user_profile_name)
        with open(f"system_data/user_profiles/{user_profile_name}/{user_profile_name}_data.json", "r") as f:
            user_profile_data = json.load(f)
        return user_profile_data

def update_stats(user_profile_data: dict, question_object_data: dict) -> dict:#Private Function
    user_profile_data = system_data_user_stats.update_stat_total_questions_in_database(user_profile_data)
    user_profile_data = system_data_user_stats.print_and_update_revision_streak_stats(user_profile_data)
    user_profile_data["settings"]["subject_settings"] = build_subject_settings(user_profile_data, question_object_data)
    user_profile_data = system_data_user_stats.calculate_average_questions_per_day(user_profile_data)
    user_profile_data = system_data_user_stats.calculate_total_in_circulation(user_profile_data)
    user_profile_data = system_data_user_stats.calculate_average_num_questions_entering_circulation(user_profile_data)
    user_profile_data = system_data_user_stats.initialize_and_update_questions_exhausted_in_x_days_stat(user_profile_data)
    user_profile_data = system_data_user_stats.determine_total_eligible_questions(user_profile_data)
    return user_profile_data

def update_score(status:str, unique_id:str, user_profile_data: dict, question_object_data: dict, time_spent = None) -> dict: #Public Function
    # The question just answered will be sitting in the "in_circulation_is_eligible" pile
    # We need to update the metrics, then place it in the "in_circulation_not_eligible" pile    
    # Initial Check, has the question already been updated?
    try:
        # We will be moving the question anyway so we're going to extract the question object
        question_object = user_profile_data['questions']["in_circulation_is_eligible"].pop(unique_id) 
        # Removes the question from the in_circulation_is_eligible pile
    except KeyError:
        # Attempting to update the score of a question that has already been updated
        return user_profile_data
    def _calculate_average_time(raw_data_list):
        # Convert to floats
        time_data = [float(i) for i in raw_data_list]
        # Reject outliers
        filtered_times = helper.reject_outliers(time_data)
        average_time = sum(filtered_times)/len(filtered_times)
        return average_time
    def _increment_total_answer(question_object: dict):
        if question_object.get("total_answers") == None:
            question_object["total_answers"] = 1
        else:
            question_object["total_answers"] += 1
        return question_object
    def _reinforce_time(question_object: dict, time_spent: datetime, status: str):
        override_mechanism = False # Override mechanism ensures if on revision one, set time to at least 60 seconds, driving the average up, set to override so we do not force repeat the question on the first revision

        n = 7.25 # Hard n second recall, if below n seconds, do not override. 7.25 is the developers current overall answer average
        print(f"Time taken to answer: {time_spent}/{n}") # For my own gratification, feel free to remove.

        # Need to first add the time_spent to the question_objects array of answer_times:
        time_spent = str(time_spent.total_seconds()) # get total seconds and stringify
        
        # if question_object["revision_streak"] == 1 or question_object["revision_streak"] == 2 or question_object["revision_streak"] == 3:
        #     if float(time_spent) < 60.0: # By forcing at least one 60 second answer time, we drive the average up, reducing the number of forced repeats during early revisions, we do strip outliers so eventually the large minute time may get stripped from the calculations.
        #         time_spent = str('60.0')
        #         override_mechanism = True
        if question_object.get("answer_times") == None:
            question_object["answer_times"] = [time_spent]
        else:
            question_object["answer_times"].append(time_spent)
        if status != "incorrect" and override_mechanism == False:
            average_time = _calculate_average_time(question_object["answer_times"])
            if average_time < n:
                average_time = n
            # Criteria is a bit obnoxious for an absolute comparison. In effect the absolute, you have to beat your average causes even well known questions to constantly be repeated without benefit
            # Two thoughts
            # Percentage variance (acceptable range)
            # if float(time_spent) >= (average_time*1.10): # If within 10% of average, do not repeat. This adds a range to the hard-repeat -> if average is 6 seconds and user answers at 6.1 seconds, we don't repeat.
            #     time_spent_text = round(float(time_spent), 2)
            #     average_time_text = round((average_time*1.10),2)
            #     print(f"{time_spent_text} >= {average_time_text}, status overidden to 'repeat'")
            #     status = "repeat"
        return [question_object, status]
        # Function Notes:
        # There is a strange temporal perception going on. What I perceive as 5 seconds has varied from just 2 seconds to 8 seconds. Sometimes answering something quickly and seeing it took 8 seconds, or thinking I spent longer on something, but it only took 1-3 seconds. There may be something to investigate here.

    #############################################################################
    # Potential Status Overide based on time required to answer depending on average time to answer
    # Weighing of average time only is factored based on correct answers
    question_object = _increment_total_answer(question_object)
    # If no time is given when updating the score, then GUI does not implement this feature:
    # This if statement exists to make time reinforcement an optional system
    if time_spent != None:
        return_info:        list    = _reinforce_time(question_object, time_spent, status)
        question_object:    dict    = return_info[0]
        status:             str     = return_info[1]
    ######################################
    module_name = question_object_data[unique_id]["module_name"]
    # print(f"    Question is from module < {module_name} >")
    ############# We Have Multiple Values to Update ########################################
    # Increment Revision Streak by 1 if correct, or decrement by 1 if not correct
    if status == "correct":
        # Sometimes we are able to answer something correctly, even though the projection would say we should have forgotten about it:
        # In such instances we will increment the time_between_revisions so the questions shows less often
        if helper.within_twenty_four_hours(helper.convert_to_datetime_object(question_object["next_revision_due"])) == False:
            # print("Task failed successfully: Incrementing time between revisions")
            question_object["time_between_revisions"] += 0.005 # Increment spacing by .5%
            print(f"Time Between Revisions Updated +0.5% for id:{unique_id}")
        question_object["revision_streak"] += 1
        if module_name == "Quizzer Tutorial" or module_name == "quizzer tutorial":
            question_object["revision_streak"] = 1000 # Never show this again
    elif status == "incorrect":
        # The projection was set, but the user answers it incorrectly despite the fact that the algorithm predicted they should still remember it.
        # In such a case we will decrement the time between revisions so it shows more often
        if helper.within_twenty_four_hours(helper.convert_to_datetime_object(question_object["next_revision_due"])) == True:
            # memory model is extremely aggressive, therefore if we do not get the answer correct the k constant should be reduced more aggressively (flattening the curve)
            k_reduction = 0 # the constant k that determines the curve
            # But two possible conditions exist, either we are in 
            #   - the initial revision stage (1-5)
            if question_object["revision_streak"] >= 6:
                k_reduction = 0.015
            #   - outside the initial revision stage
            #   k_reduction remains 0
            question_object["time_between_revisions"] -= k_reduction # Decrement by k_reduction
        question_object["revision_streak"] -= 1 #Less discouraging then completely resetting the streak, if questions aren't getting completely reset we make room for more knowledge faster
        # At this point revision streak is no longer representative of a streak of correct replies, but rather a value to help determine spacing
        if question_object["revision_streak"] < 1:
            question_object["revision_streak"] = 1
    # print(f"Revision streak was {check_variable}, streak is now {question_object['revision_streak']}")
    ###################
    # User stat representing how many questions the user has answered over lifetime
    user_profile_data = system_data_user_stats.increment_questions_answered(user_profile_data)
    ###################
    # Change the last_revised property to datetime.now() since we just revised it at time of now
    question_object["last_revised"] = helper.stringify_date(datetime.now())
    ###################
    # Calculate the next time the question will be due for revision
    # That is, predict when the user will forget the answer to the question and set the due date to right before that point in time
    question_object["next_revision_due"] = helper.convert_to_datetime_object(question_object["next_revision_due"])
    question_object = system_data_question_stats.calculate_next_revision_date(status, question_object)
    question_object["next_revision_due"] = helper.stringify_date(question_object["next_revision_due"])
    ###################
    # Update question's history stats
    question_object = system_data_question_stats.update_question_history(question_object, status)
    ###################
    # Update all the other stats
    # redetermines eligibility, if the question was given a status of incorrect this will show the question as eligible to answer
    question_object = update_user_question_stats(question_object, unique_id, user_profile_data, question_object_data)
    ###################
    # Update data structure
    # We need to move the question we just answered from the "in_circulation_is_eligible" pile to the "in_circulation_not_eligible" pile
    # We've already removed it from the "in_circulation_is_eligible_pile"
    write_data = {unique_id: question_object}
    if question_object["is_eligible"] == False:
        user_profile_data["questions"]["in_circulation_not_eligible"].update(write_data)
    else:
        user_profile_data["questions"]["in_circulation_is_eligible"].update(write_data)
    # We also need to update any stats directly relating whats in the piles
    # Most of these stats just use O(1) functions
    user_profile_data = update_stats(user_profile_data, question_object_data)
    # FIXME potential time sinks
    # So update stats iterates the entire question list twice
    # calculation of average_questions_per_day, subtract old value, add new value
    # print_and_update_revision_streak_stats has for loops
    return user_profile_data

def update_circulating_non_eligible_questions(user_profile_data, question_object_data):
    '''
    Looks over the questions in the "in_circulation_non_eligible" pile, updates them, and if any are eligible moves them to the "in_circulation_is_eligible" pile
    '''
    # print(f"def update_circulating_non_eligible_questions(user_profile_data, question_object_data)")
    # questions_to_remove_from_not_eligible_pile = []
    eligible_questions_counter = 0
    user_question_list = user_profile_data["questions"]["in_circulation_not_eligible"].copy()
    # We are directly going through questions that are in circulation
    # print("   ",len(user_question_list), "Questions in the in_eligible pile")
    for question_id in user_question_list.keys():
        question_object = user_profile_data["questions"]["in_circulation_not_eligible"][question_id]
        question_object["in_circulation"] = True # Error handling, some questions are in here, but marked not in circulation
        question_object = update_user_question_stats(question_object, question_id, user_profile_data, question_object_data)
        if question_object["is_eligible"] == True:
            eligible_questions_counter += 1
            write_data = {question_id: question_object}
            user_profile_data["questions"]["in_circulation_is_eligible"].update(write_data)
            del user_profile_data["questions"]["in_circulation_not_eligible"][question_id]

    # print(f"    Moving {eligible_questions_counter} questions from in_circulation_not_eligible pile to in_circulation_is_eligible pile")
    return user_profile_data

def add_new_question_object(
        user_profile_data: dict, #Not required, but does pass through for some functions, more efficient
        question_object_data: dict, 
        all_module_data: dict,
        unique_id: str = None, #For admin only, when entering new questions for the tutorial module
        primary_subject: str = "miscellaneous",
        subject: list = ["miscellaneous"],
        related: list = None,
        question_text = None, question_image = None, question_audio = None, question_video = None,
        answer_text = None, answer_image = None, answer_audio = None, answer_video = None,
        module_name: str = None) -> dict:
    # print(f"def add_new_question_object(<properties>)")
    # This is the system data version, verify_new_question builds the question object based on the inputs and checks if its valid,
    # First we need to generate the complete object
    module_name = module_name.lower()
    question_object = verify_new_question(
        user_profile_data   = user_profile_data,
        subject             = subject,
        related             = related,
        question_text       = question_text,
        question_image      = question_image,
        question_audio      = question_audio,
        question_video      = question_video,
        answer_text         = answer_text,
        answer_image        = answer_image,
        answer_audio        = answer_audio,
        answer_video        = answer_video,
        module_name         = module_name
    )
    if question_object == None:
        # if verification failed, then the result is a None value, check for this
        return None
    # Assign the question_object with an author field which is the user's uuid
    user_uuid = user_profile_data["uuid"]
    question_object["author"] = user_uuid # match the question to the user
    unique_id = question_object["id"]
    # print(user_uuid)
    # print(question_object)
    # Write the question to firestore DB
    # question_object = firestore_db.update_question_in_firestore(unique_id, question_object)
    write_data = {unique_id: question_object}
    # Add the verified question object to the master question object database

    question_object_data.update(write_data)
    update_question_object_data(question_object_data) 
    # Add the id to the user's profile
    data = update_user_question_stats({}, unique_id, user_profile_data, question_object_data)
    user_profile_data["questions"]["unsorted"].update({unique_id: data})
    user_profile_data["questions"] = sort_questions(user_profile_data, question_object_data)
    user_profile_data = update_stats(user_profile_data, question_object_data)
    update_user_profile(user_profile_data)

    return question_object

def verify_module_in_user_profile(user_profile_data, all_module_data):
    '''
    Scans the module questions (all of the the user modules)
    If any are missing from the user_profile add them
    After adding missing questions, scans through questions in the reserve bank, and circulating piles. and verifies where the question should be based on the module
    '''
    user_modules = user_profile_data["settings"]["module_settings"]["module_status"].keys()
    all_user_questions = {}
    for pile_name, pile in user_profile_data["questions"].items():
        all_user_questions.update(pile)
    deletion_queue = [] # List of module names
    for module_name in user_modules:
        try:
            module_data = all_module_data[module_name].copy()
        except KeyError:
            # This error was introduced on account of editing every question of one module, changing the module names, so that no questions were left in that module
            #   This caused the deletion of the empty module
            #   In Turn The program went to check for missing questions in that module and could not find the module
            # So what do we need to do fix this?
            # First handle the exception with this try except block
            # Since the module name exists in the user file, but not in the system, we should delete it from the module_status setting
            deletion_queue.append(module_name)
        module_questions = module_data["questions"]
        for question_id in module_questions: # module_questions is a list of id's
            # if we find a question_id in the module that a user owns, but the user doesn't have it, throw it in the unsorted pile
            if question_id not in all_user_questions:
                user_profile_data["questions"]["unsorted"].update({question_id: {}})  

    # To avoid a RunTimeError: dictionary changed size during iteration error  
    for module_name in deletion_queue:
        del user_profile_data["settings"]["module_settings"]["module_status"][module_name]
    return user_profile_data

def activate_module_in_user_profile(name_of_module, user_profile_data, all_module_data, question_object_data):
    '''
    adds the module to the user settings
    Verifies the user has all the questions for that module
    Sorts the new questions into the reserve bank
    Scans the deactivated pile for any questions belonging to that module, then puts them in the reserve bank
    '''
    status = user_profile_data["settings"]["module_settings"]["is_module_active_by_default"]
    user_profile_data["settings"]["module_settings"]["module_status"].update({name_of_module: True})
    sort_questions(user_profile_data, question_object_data) # Calls verification -> moves questions to reserve bank
    module_to_activate = all_module_data[name_of_module]["questions"]
    for question_id in module_to_activate:
        if question_id in user_profile_data["questions"]["deactivated"]:
            # Move the question to the reserve_bank
            user_profile_data["questions"]["reserve_bank"].update({question_id: user_profile_data["questions"]["deactivated"][question_id]})
            # Delete from deactivated pile
            del user_profile_data["questions"]["deactivated"][question_id]
    update_user_profile(user_profile_data)
    return user_profile_data

def deactivate_module_in_user_profile(name_of_module, user_profile_data, all_module_data, question_object_data):
    '''
    Can't deactivate something unless we've first added it, this is controlled in the frontend
    Verifies the user has all questions for that module
    Sorts the nwe questions into the reserve bank
    Sets the status to false
    Scans three piles, reserve_bank, in_circulation_not_eligible, in_circulation_is_eligible, moves those questions to the deactivated pile
    '''
    # print(f"def deactivate_module")
    user_profile_data["settings"]["module_settings"]["module_status"].update({name_of_module: False})
    sort_questions(user_profile_data, question_object_data)
    module_to_deactivate = all_module_data[name_of_module]["questions"]
    for question_id in module_to_deactivate:
        # Scan the reserve bank
        if question_id in user_profile_data["questions"]["reserve_bank"]:
            user_profile_data["questions"]["deactivated"].update({question_id: user_profile_data["questions"]["reserve_bank"][question_id]})
            del user_profile_data["questions"]["reserve_bank"][question_id]
        # Scan the "in_circulation_not_eligible" pile
        elif question_id in user_profile_data["questions"]["in_circulation_not_eligible"]:
            user_profile_data["questions"]["deactivated"].update({question_id: user_profile_data["questions"]["in_circulation_not_eligible"][question_id]})
            del user_profile_data["questions"]["in_circulation_not_eligible"][question_id]   
        # Scan the "in_circulation_is_eligible"
        elif question_id in user_profile_data["questions"]["in_circulation_is_eligible"]:
            user_profile_data["questions"]["deactivated"].update({question_id: user_profile_data["questions"]["in_circulation_is_eligible"][question_id]})
            del user_profile_data["questions"]["in_circulation_is_eligible"][question_id]                       
    update_user_profile(user_profile_data)
    return user_profile_data

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


async def plot_x_over_time(data, target):
    # Parse the data into two lists: dates and counts
    dates = [datetime.strptime(date, "%Y-%m-%d") for date in data.keys()]
    counts = list(data.values())
    
    # Calculate the cumulative average (smooth line)
    cumulative_counts = 0
    averages = []
    for i, count in enumerate(counts):
        cumulative_counts += count
        averages.append(cumulative_counts / (i + 1))
    
    # Create the plot
    plt.figure(figsize=(10, 5))  # Adjust figure size as needed
    
    # Plot the jagged line (actual counts per day)
    plt.plot(dates, counts, marker='o', linestyle='-', linewidth=2, label='Questions Answered (Daily)')
    
    # Plot the smooth line (cumulative average)
    plt.plot(dates, averages, linestyle='--', linewidth=2, label='Average Questions Answered (Cumulative)')
    
    # Plot the straight red line (user target)
    plt.axhline(y=target, color='red', linestyle='-', linewidth=2, label=f'Target Questions Per Day ({target})')
    
    # Add titles and labels
    plt.title("Questions Answered Over Time", fontsize=16)
    plt.xlabel("Date", fontsize=12)
    plt.ylabel("Questions Answered", fontsize=12)
    
    # Format the x-axis for readability
    plt.xticks(rotation=45, ha='right')
    plt.tight_layout()  # Adjust layout to fit labels
    
    # Add a legend
    plt.legend(fontsize=12)
    
    # Save the plot as an image file
    plt.savefig("system_data/non_question_assets/questions_answered_with_target.png")
    plt.close()
    print("Graph saved as 'questions_answered_with_target.png'") 


def get_next_question(user_profile_data, amount_of_rs_one_questions):
    '''
    Selection Algorithm
    determines which question will be shown to the user next based on their profile data and settings
    Currently ensures that presented questions prioritize questions with lower revision streaks over questions with higher streaks
    '''
    # Now based on the random_weight we will choose a question within the range
    user_questions: dict = user_profile_data["questions"]["in_circulation_is_eligible"]
    # To ensure questions are not presented back to back, we will shuffle the order of the keys every time we pick a new question
    user_questions = helper.shuffle_dictionary_keys(user_questions)
    for i in range(1, 101):
        for question_id, question_object_user_data in user_questions.items():
            check_var = question_object_user_data["revision_streak"]
            due_date = helper.convert_to_datetime_object(question_object_user_data["next_revision_due"])
            overdue = False
            print(f"Selected question with RS of {check_var}")
            return question_id
            # Questions that are not close to the due date won't be presented
            # If the question hits this condition it indicates it is overdue for revision, beyond the acceptable margin

            # Define which questions get immediate priority
            # Questions that have just been added go first
            if i == 1:
                if check_var == 1:
                    print(f"Selected question with RS of {check_var}")
                    return question_id
            # Questions that the user is still actively learning (has not gone to medium-long term memory)
            elif i == 2:
                if check_var <= 6:
                    print(f"Selected question with RS of {check_var}")
                    return question_id         
            # Questions the user is overdue for answering (At risk of forgetting that information)           
            elif i == 3:   
                if helper.within_twenty_four_hours(helper.convert_to_datetime_object(question_object_user_data["next_revision_due"])) == False:
                    overdue = True
                    print(due_date)
                if overdue == True:
                    print(f"Selected question with RS of {check_var}")
                    print(f"Question is overdue")
                    return question_id
            # All other questions
            elif i >= 4:
                print(f"Selected question with RS of {check_var}")
                return question_id                  


                
# Two design philosophies from this point on:

# Closed authorship
# Only the original author of a module can modify that module
# Modules are unique by title
# When modules are built, they check the author of the question object to determine the author of the module
# When question objects are added, only modules the user has authored may be selected for entry

# Opensource Community System
# Alternatively each module could adopt the open-source model
# User's can author a module
# User's can pull in community modules
# Either way all user's can add to any module
# Each question in the module will have the author attached to it -> you would be able to see the major and minor contributors to a module

# Individual questions can be disabled by the user, for that user #FIXME
# Questions can be rated in the future #FIXME
# Bad rating mark a question for takedown -> community consensus will determine whether questions stay in the database or not
# Allow user's to delete their own questions and edit all questions

# The zeitgeist would be of community collaboration, this would allow information to disseminate freely, anyone who spots a falsehood can edit a question to be better.
# Poorly rated questions that fall below 50% consensus would be removed, but a minimum number of rating would be required. Say at least 25% of the people who have the module need to vote on it before the removal can be triggered.
#   This way a mechanism still exists to remove shit quality questions
#   This also leaves the door for the entire community to improve the quality of question objects

# So WHAT?
#   To start off when a new question is entered by a user, it's entered into the server database
#   The server list of modules and all questions are issued to every user
#       This list of modules is accessible by an option in the menu
#       Selecting a module imports all of those questions in the module into the user's "pile" of questions
#   The add_new_question objects needs to:
#   - add the object to the server database -> which rebuilds the module_data list as well
#   - fetch the new module_list and return it to the user
#   - Add the question to the user's unsorted pile
#   - sort the user's questions["unsorted"]
#   - return question_object_data, all_module_data, user_profile_data