from lib import helper
from question_functions import update_questions
from stats_functions import stats, update_statistics
from datetime import datetime, date, timedelta
from module_functions import modules
import time
import json
import math
import random
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
        user_profile_data: dict = None, #Not required, but does pass through for some functions, more efficient
        id: str = None,
        primary_subject: str = "miscellaneous",
        subject: list = ["miscellaneous"],
        related: list = None,
        question_text = None, question_image = None, question_audio = None, question_video = None,
        answer_text = None, answer_image = None, answer_audio = None, answer_video = None,
        module_name: str = None) -> dict:
    '''
    receives data as input and outputs a question object with all fields not defined set to None
    Used in conjunction with the helper.add_question_object(question_object) function
    Returns a question_object if it's valid
    Returns None if the question_object is not valid
    '''
    question_object = {}
    # Make exception for "Quizzer Tutorial Module", all other questions running through this function will get assigned a question_id proper
    if module_name != "Quizzer Tutorial":
        user_uuid = helper.get_user_uuid()
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



# This module holds any function that governs or alters a question object
#######################################################################
#######################################################################
#######################################################################

def initialize_and_update_question_properties(user_profile_data: dict) -> dict:
    '''
    Update all questions in the user's profile data
    Updates each index as well for quicker lookup by other functions
    '''
    indices = {}
    eligiblity_index = {}
    revision_streak_index = {}
    subject_question_index = {}
    subject_in_circulation_index = {}
    questions_data = user_profile_data["questions"]
    settings_data = user_profile_data["settings"]
    for unique_id, question_object in questions_data.items():
        file_question = {unique_id: question_object}
        # I'm getting a strange bug where the question object morphs into a NoneType object

        # To accomplish a minimal time complexity we will update each function so that the function takes the question object, modifies it, then returns it: For one operation per object
        # Old system scans every question in the list for every property, creating far more operations than necessary
        # # First initialize properties that don't exist with first time values:    

        question_object = update_questions.initialize_in_circulation_property(question_object, settings_data)
        
        question_object = update_questions.initialize_revision_streak_property(question_object)
        
        question_object = update_questions.initialize_last_revised_property(question_object)
        
        question_object = update_questions.initialize_next_revision_due_property(question_object)
        
        question_object = update_questions.initialize_question_media_properties(question_object)
        
        question_object = update_questions.initialize_answer_media_properties(question_object)
        
        question_object = update_questions.initialize_time_between_revisions_property(question_object, settings_data)
        
        question_object = update_questions.initialize_academic_sources_property(question_object)

        question_object = update_questions.determine_eligibility_of_questions(question_object, settings_data)

        question_object = update_questions.update_is_module_active_property(question_object, settings_data)
        # Add question to index of eligible questions for the populate_quiz function to use:
        question_object = update_questions.determine_question_subjects(question_object)
        question_object = update_questions.determine_related_concepts(question_object)
        question_object = update_questions.calculate_average_shown(question_object)
        # Create indexes while iterating over the question list:
        ## revision_streak_index:
        revision_streak = question_object["revision_streak"]
        if question_object["in_circulation"] == True:
            if revision_streak_index.get(revision_streak) == None:
                revision_streak_index[revision_streak] = {}
                revision_streak_index[revision_streak].update(file_question)
            elif revision_streak_index.get(revision_streak) != None:
                revision_streak_index[revision_streak].update(file_question)
    
    
        ## eligible questions index (all questions which are eligible)
        if question_object["is_eligible"] == True:
            eligiblity_index[unique_id] = question_object
    
        ## Questions by subject index
        ### List of subjects can be derived off this index
        ### Total questions by subject can be derived from this index
        subjects_list = question_object["subject"]
        for sub in subjects_list:
            if sub not in subject_question_index:
                subject_question_index[sub] = {}
                subject_question_index[sub].update(file_question)
            elif sub in subject_question_index:
                subject_question_index[sub].update(file_question)
            if question_object["in_circulation"] == True:
                if sub not in subject_in_circulation_index:
                    subject_in_circulation_index[sub] = {}
                    subject_in_circulation_index[sub].update(file_question)
                elif sub in subject_in_circulation_index:
                    subject_in_circulation_index[sub].update(file_question)
        
        
    indices["eligibility_index"] = eligiblity_index
    indices["revision_streak_index"] = revision_streak_index
    indices["questions_by_subject_index"] = subject_question_index
    indices["subject_in_circulation_index"] = subject_in_circulation_index
    user_profile_data["indices"] = indices
    user_profile_data["questions"] = questions_data
    user_profile_data["settings"] = settings_data
    return user_profile_data

def calculate_next_revision_date(status, dictionary): #Private Function
    '''
    The core of Quizzer, predicated when the user will forget the information contained in the questions helps us accelerate learning to the max extent possible
    Runs the algorithm necessary for predicting when the User will forget the information and projects a date on which the user should revise next.
    '''
    # Function is isolated because algorithm for determining the next due date
    # is very much in need of an update to a more advanced determination system.
    # Needs to consider factors like what other questions and concepts the user knows and are related to question at hand
    
    ################################################################################################################3
    # I noticed that the same questions would always appear next to each other:
    # To offset this we will add a random amount of hours to the next_revision_due
    # Based on the current revision_streak we will select a range:
    if dictionary["revision_streak"] == 1:
        random_variation = random.randint(1,4)
    elif dictionary["revision_streak"] <= 3:
        random_variation = random.randint(1,6)
    elif dictionary["revision_streak"] <= 6:
        random_variation = random.randint(1,8)
    elif dictionary["revision_streak"] <= 10:
        random_variation = random.randint(1,12)
    elif dictionary["revision_streak"] <= 15:
        random_variation = random.randint(1,14)
    else:
        random_variation = random.randint(6, 24)
    if status == "correct":
        # Forgetting Curve study formula
        dictionary["next_revision_due"] = datetime.now() + timedelta(hours=(24 * math.pow(dictionary["time_between_revisions"],dictionary["revision_streak"]))) + timedelta(hours=random_variation) #principle * (1.nn)^x
        # print(f"adding {random_variation} hours to next_revision_due")
        # print(f"{timedelta(hours=random_variation)}")
    else: # if not correct then incorrect, function should error out if status is not fed into properly:
        # Intent is to make an incorrect question due immediately and of top priority
        dictionary["next_revision_due"] = datetime.now()
    return dictionary["next_revision_due"]

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

def update_user_question_stats(question_object: dict, unique_id, user_profile_data: dict, question_object_data: dict) -> dict:
    settings_data = user_profile_data["settings"]
    question_object = update_questions.initialize_revision_streak_property(question_object)
    question_object = update_questions.initialize_last_revised_property(question_object)
    question_object = update_questions.initialize_next_revision_due_property(question_object)
    question_object = update_questions.initialize_in_circulation_property(question_object, settings_data)
    question_object = update_questions.initialize_time_between_revisions_property(question_object, settings_data)
    question_object = update_questions.calculate_average_shown(question_object)
    question_object = update_questions.determine_eligibility_of_question_object(question_object, settings_data)
    question_object = update_questions.update_is_module_active_property(question_object, unique_id, user_profile_data, question_object_data)
    return question_object
