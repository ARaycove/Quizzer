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
# Any Function that does not call another function (besides external libs)
def build_first_time_stats_data(user_profile_data: dict = None) -> dict:#Private Function
    '''
    Initial stats for new users
    '''
    stats_data = {}
    stats_data["questions_answered_by_date"] = {f"{datetime.now()}": 0}
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
        print(f"Profile {user_name} already exists")
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

def calculate_question_id(question_object: dict, user_profile_data: dict) -> dict: #Private Function
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
    user_uuid = str(user_profile_data["uuid"])
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
    # Validate question_object has a module_name attached NOTE Every question_object must belong to a module
    if question_object["module_name"] == "":
        return is_valid
    if question_object["module_name"] == None:
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
    if module_name != "Quizzer Tutorial":
        user_uuid = user_profile_data["uuid"]
        question_object["id"] = calculate_question_id(user_uuid)
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
    questions_data = {}
    questions_list = []
    question_one = (verify_new_question(
        id = "tutorial_question_one",
        question_text = "Welcome to Quizzer: Click the question to flip over to the answer",
        answer_text = "Now press the checkmark if you get a question correct, or press the cancel circle if you got it wrong. Quizzer is self-scored, and relies on you being honest with yourself!",
        module_name = "Quizzer Tutorial"
    ))

    questions_list.extend([question_one])

    return questions_list

def initialize_question_object_data_json():
    '''
    Creates the template for which user_profiles can initialize their question list
    '''
    question_object_data = {}
    quizzer_tutorial_questions = generate_quizzer_tutorial_question_objects()
    for question_object in quizzer_tutorial_questions:
        unique_id = question_object["id"]
        write_data = {unique_id: question_object}
    question_object_data.update(write_data)
    verify_system_data_directory()
    with open("system_data/question_object_data.json", "w+") as f:
        json.dump(question_object_data, f)

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
        initialize_question_object_data_json()
        with open("system_data/question_object_data.json", "r") as f:
            question_object_data = json.load(f)
        return question_object_data

def update_question_object_data(question_object_data: dict) -> None:
    '''
    Updates the master question_object_data with the updated information
    '''
    import json
    from initialization_functions import initialize
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
        print(e, "Now initializing subject_data.json")
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
        print(e, "Now initializing concept_data.json")
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
    quizzer_tutorial = module_data["Quizzer Tutorial"]
    for unique_id in quizzer_tutorial["questions"]:
        write_data = {unique_id: {}}
        questions_data["unsorted"].update(write_data) #NOTE tutorial questions will immediately go into the unsorted "pile"
    # Send the data back to the add_new_user(user_name) function which calls this 
    return questions_data

def build_subject_settings(user_profile_data: dict, question_object_data) -> dict: #Private Function
    '''
    Builds or rebuilds the subject settings for the specific user
    '''
    print("def settings.build_subject_settings(user_profile_data: dict, question_object_data) -> dict")
    subject_settings = {}
    # serves as a template for later
    initial_subject_setting = {}
    initial_subject_setting["interest_level"] = 10
    initial_subject_setting["priority"] = 9
    initial_subject_setting["total_questions"] = 0
    initial_subject_setting["num_questions_in_circulation"] = 0
    initial_subject_setting["total_activated_questions"] = 0
    # print(initial_subject_setting)
    # Iterate over every question id contained in the user's 
    for pile_name, pile in user_profile_data["questions"].items():
        # Get all the subjects mentioned in each question
        for unique_id, question_object in pile.items():
            subject_list = question_object_data[unique_id]["subject"]
            for subject in subject_list:
                if subject not in subject_settings:
                    subject_settings[subject] = initial_subject_setting
                    # Tally up the questions that are in_circulation
                    if question_object.get("in_circulation") == True:
                        subject_settings[subject]["num_questions_in_circulation"] += 1
                    # Build an index of user questions sorted by subject
                    subject_settings[subject]["questions"] = []
                    subject_settings[subject]["questions"].append(unique_id)
                    # Tally Total questions
                    subject_settings[subject]["total_questions"] += 1
                    # Tally Total activated questions
                    if question_object.get("is_module_active") == True:
                        subject_settings[subject]["total_activated_questions"] += 1
                else:
                    subject_settings[subject]["questions"].append(unique_id)
                    if question_object.get("in_circulation") == True:
                        subject_settings[subject]["num_questions_in_circulation"] += 1
                    subject_settings[subject]["total_questions"] += 1
                    if question_object.get("is_module_active") == True:
                        subject_settings[subject]["total_activated_questions"] += 1

    print("    Determining if subjects has available questions")
    for subject in subject_settings:
        if subject_settings[subject]["total_activated_questions"] == subject_settings[subject]["num_questions_in_circulation"]:
            subject_settings[subject]["has_available_questions"] = False
        else:
            subject_settings[subject]["has_available_questions"] = True
        # print(f"{subject.title():25} has {in_circulation_count:5}/{total_count:<5} currently in circulation")
    subject_settings = helper.sort_dictionary_keys(subject_settings)
    print()
    print(f"    The user's subject settings are now:")
    for key, value in subject_settings.items():
        print(f"    {key:50}: {value}")
    return subject_settings

def build_module_settings(user_profile_data: dict, question_object_data: dict) -> dict:
    # First check if we've already built module_settings for this user, since we will reuse this function for subsequent
    print()
    print("def settings.build_module_settings(user_profile_data:dict, question_object_data: dict) -> dict") 
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
            module_name = question_object_data[unique_id]["module_name"]
            # Only add to list, never delete from it
            if module_name not in module_settings["module_status"]:
                module_settings["module_status"][module_name] = default_status
    
    return module_settings

def build_first_time_settings_data(user_profile_data, question_object_data) -> dict:
    settings_data = {}
    settings_data["quiz_length"] = 25
    settings_data["time_between_revisions"] = 1.2
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
    questions_data = user_profile_data["questions"]
    questions_to_remove_from_unsorted_pile = [] # list of id's since we can't mutate a dictionary while iterating over it
    for pile_name, pile in questions_data.items():
        if pile_name == "unsorted":
            for unique_id, question_object in pile.items():
                # First update the question properties, ensuring data we are evaluating is accurate
                question_object = update_user_question_stats(question_object, unique_id, user_profile_data, question_object_data)


                # First check if the module that the question belongs to is active, if the
                if question_object["is_module_active"] == False:
                    write_data = {unique_id: question_object}
                    questions_data["deactivated"].update(write_data)
                    questions_to_remove_from_unsorted_pile.append(unique_id)
                # Module is active, therefore eligible to be placed into circulation
                elif question_object["in_circulation"] == False:
                    write_data = {unique_id: question_object}
                    questions_data["reserve_bank"].update(write_data)
                    questions_to_remove_from_unsorted_pile.append(unique_id)
                # Conditions if in_circulation == True
                elif question_object["is_eligible"] == True and question_object["in_circulation"] == True:
                    write_data = {unique_id: question_object}
                    questions_data["in_circulation_is_eligible"].update(write_data)
                    questions_to_remove_from_unsorted_pile.append(unique_id)
                elif question_object["is_eligible"] == False and question_object["in_circulation"] == True:
                    write_data = {unique_id: question_object}
                    questions_data["in_circulation_not_eligible"].update(write_data)
                    questions_to_remove_from_unsorted_pile.append(unique_id)
    
    # Batch delete these id's from the unsorted pile now that they've been moved to the appropriate pile
    for unique_id in questions_to_remove_from_unsorted_pile:
        del questions_data["unsorted"][unique_id]
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
    print("def update_user_question_stats(question_object: dict, unique_id, user_profile_data: dict, question_object_data: dict) -> dict")
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
        print(f"Question Object has type {type(question_object)}")
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
        print(f"Creating user profile with name {user_name}")
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
        print(e, f"Generating user_profile: {user_profile_name}")
        question_object_data = get_question_object_data()
        user_profile_data = add_new_user(user_profile_name, question_object_data)
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


def update_score(status:str, unique_id:str, user_profile_data: dict, question_object_data: dict) -> dict: #Public Function
    print(f"def update_score(status:str, id:str, user_profile_data: dict) -> dict")
    print(f"    Updating < {unique_id} > with status of < {status} >")
    # The question just answered will be sitting in the "in_circulation_is_eligible" pile
    # We need to update the metrics, then place it in the "in_circulation_not_eligible" pile
    check_variable = "" # Used to aid in print statements, a temporary place to store values
    # We will be moving the question anyway so we're going to extract the question object
    question_object = user_profile_data['questions']["in_circulation_is_eligible"].pop(unique_id) #Removes the question from the in_circulation_is_eligible pile
    module_name = question_object_data[unique_id]["module_name"]
    print(f"    Question is from module < {module_name} >")
    ############# We Have Multiple Values to Update ########################################
    ###################
    # Increment Revision Streak by 1 if correct, or decrement by 3 if not correct
    check_variable = question_object["revision_streak"]
    if status == "correct":
        # Sometimes we are able to answer something correctly, even though the projection would say we should have forgotten about it:
        # In such instances we will increment the time_between_revisions so the questions shows less often
        if helper.within_twenty_four_hours(helper.convert_to_datetime_object(question_object["next_revision_due"])) == False:
            print("Task failed successfully: Incrementing time between revisions")
            question_object["time_between_revisions"] += 0.005 # Increment spacing by .5%
        question_object["revision_streak"] += 1
        if module_name == "Quizzer Tutorial":
            question_object["revision_streak"] = 1000 # Never show this again
    elif status == "incorrect":
        # The projection was set, but the user answers it incorrectly despite the fact that the algorithm predicted they should still remember it.
        # In such a case we will decrement the time between revisions so it shows more often
        if helper.within_twenty_four_hours(helper.convert_to_datetime_object(question_object["next_revision_due"])) == True:
            question_object["time_between_revisions"] -= 0.005 # Decrement by 0.5%
        question_object["revision_streak"] -= 3 #Less discouraging then completely resetting the streak, if questions aren't getting completely reset we make room for more knowledge faster
        # At this point revision streak is no longer representative of a streak of correct replies, but rather a value to help determine spacing
        if question_object["revision_streak"] < 1:
            question_object["revision_streak"] = 1
    print(f"Revision streak was {check_variable}, streak is now {question_object['revision_streak']}")



    ###################
    # User stat representing how many questions the user has answered over lifetime
    user_profile_data = system_data_user_stats.increment_questions_answered(user_profile_data)
    

    
    ###################
    # Change the last_revised property to datetime.now() since we just revised it at time of now
    check_variable = question_object["last_revised"]
    print(f"This question was last revised on {check_variable}")
    question_object["last_revised"] = helper.stringify_date(datetime.now())
    
    
    
    ###################
    # Calculate the next time the question will be due for revision
    # That is, predict when the user will forget the answer to the question and set the due date to right before that point in time
    question_object["next_revision_due"] = helper.convert_to_datetime_object(question_object["next_revision_due"])
    question_object = system_data_question_stats.calculate_next_revision_date(status, question_object)
    question_object["next_revision_due"] = helper.stringify_date(question_object["next_revision_due"])
    check_variable = question_object["next_revision_due"]
    print(f"The next revision is due on {check_variable}")

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
    print(f"def update_circulating_non_eligible_questions(user_profile_data, question_object_data)")
    questions_to_remove_from_not_eligible_pile = []
    questions_data = user_profile_data["questions"]["in_circulation_not_eligible"].copy()
    for unique_id, question_object in questions_data.items():
        question_object = update_user_question_stats(question_object, unique_id, user_profile_data, question_object_data)
        write_data = {unique_id: question_object}
        if question_object["is_eligible"] == True:
            # If the question is now eligible then add it to the is_eligible pile
            user_profile_data["questions"]["in_circulation_is_eligible"].update(write_data)
            questions_to_remove_from_not_eligible_pile.append(unique_id)

    print(f"    Moving {len(questions_to_remove_from_not_eligible_pile)} questions from in_circulation_not_eligible pile to in_circulation_is_eligible pile")
    for unique_id in questions_to_remove_from_not_eligible_pile:
        # We've already added this pair to the is_eligible pile, therefore we need to delete it from the in_circulation_not_eligible pile
        del user_profile_data["questions"]["in_circulation_not_eligible"][unique_id]

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
    print(f"def add_new_question_object(<properties>)")
    # This is the system data version, verify_new_question builds the question object based on the inputs and checks if its valid,
    # First we need to generate the complete object
    
    question_object = verify_new_question(user_profile_data, unique_id, primary_subject, subject, related, question_text, question_image, question_audio, question_video, answer_text, answer_image, answer_audio, answer_video, module_name)
    if question_object == None:
        # if verification failed, then the result is a None value, check for this
        return None
    # Assign the question_object with an author field which is the user's uuid
    user_uuid = user_profile_data["uuid"]
    question_object["author"] = user_uuid # match the question to the user


    # Now we have a complete question object
    # We need to add it to the server question_object_data -> update the server and fetch new data
    unique_id = question_object["id"]
    write_data = {unique_id: question_object}
    question_object_data.update(write_data)
    update_question_object_data(question_object_data) # Save the new question to the server
    #FIXME proper server logic to fetch and send data between it
    # Current functionality allows anyone to add questions to a pre-existing module filtered by name
    # Check if the module name already exists and the property in the module name matches the user's uuid -> Should be done on the front-end?
    data = update_user_question_stats({}, unique_id, user_profile_data, question_object_data)
    user_profile_data["questions"]["unsorted"].update({unique_id: data})
    user_profile_data = sort_questions(user_profile_data, question_object_data)
    user_profile_data = update_stats(user_profile_data, question_object_data)



# Only the original author of a module can modify that module
# Modules are unique by title
# When modules are built, they check the author of the question object to determine the author of the module
# When question objects are added, only modules the user has authored may be selected for entry

# Alternatively each module could adopt the open-source model
# User's can author a module
# User's can pull in community modules
# Either way all user's can add to any module
# Each question in the module will have the author attached to it -> you would be able to see the major and minor contributors to a module

# Individual questions can be disabled by the user, for that user #FIXME
# Questions can be rated in the future #FIXME
# Bad rating mark a question for takedown -> community consensus will determine whether questions stay in the database or not
