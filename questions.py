from lib import helper
from question_functions import update_questions
import stats
from datetime import datetime, date, timedelta
from module_functions import modules
import time
import json
import math
import random
# This module holds any function that governs or alters a question object
#######################################################################
#######################################################################
#######################################################################
def create_questions_json_file(): #Private Function
    '''
    Initializes Quizzer Tutorial Module, also includes all the tutorial questions that will get entered
    '''
    questions = {}
    id_key = "tutorial question 01"
    settings = helper.get_settings_data()
    dummy = {}
    # define initial question metadata
    dummy["id"] = "tutorial question 01"
    dummy["file_path"] = None
    dummy["file_path"] = None
    dummy["object_type"] = "question"
    dummy["subject"] = ["miscellaneous"]
    dummy["related"] = ["tutorial"]
    # define main details of the question presented
    dummy["question_text"] = "Hello, welcome to quizzer, You can click show to see the answer, If you get the question correct press yes, otherwise press no"
    dummy["question_image"] = None
    dummy["question_audio"] = None
    dummy["question_video"] = None
    # define main details of the answer to the question
    dummy["answer_text"] = "Congratulations, thats it. press the menu and add your own questions"
    dummy["answer_image"] = None
    dummy["answer_audio"] = None
    dummy["answer_video"] = None
    # define question stats
    dummy["module_name"] = "Quizzer Tutorial"
    dummy["revision_streak"] = 100
    dummy["last_revised"] = helper.stringify_date(datetime.now())
    dummy["next_revision_due"] = helper.stringify_date(datetime.now())
    dummy["in_circulation"] = False
    dummy["time_between_revisions"] = settings["time_between_revisions"]
    # add dummy question to initialize data structure
    questions[id_key] = dummy
    modules.verify_and_initialize_module("Quizzer Tutorial")
    with open(f"modules/Quizzer Tutorial/Quizzer Tutorial_data.json", "r") as f:
        initial_module = json.load(f)
    
    if initial_module["questions"] == {}:
        write_data = {dummy["id"]: dummy}
        initial_module["questions"].update(write_data)
    
    with open(f"modules/Quizzer Tutorial/Quizzer Tutorial_data.json", "w+") as f:
        json.dump(initial_module, f, indent=4)

        
def initialize_questions_json(): #Private Function
    """Checks if question.json exists. If not, create it.
    """
    try:
        questions = helper.get_question_data()
        print("questions.json exists")
    except:
        print("questions.json not found")
        print("creating questions.json with default values")
        create_questions_json_file()

def initialize_and_update_question_properties(questions_data, settings_data):
    # Reduce time complexity and update to match new data structure:
    # To aid in reducing complexity, i'm designing my own data_base system, for learning sake
    # Each property the system will need to look up later will have its own index which will be quicker
    # data_feed = {}

    # for unique_id, question_object in questions_data.items():
    #     if data_feed.get(type(question_object)) == None:
    #         data_feed[type(question_object)] = 1
    #     else:
    #         data_feed[type(question_object)] += 1
    #     if data_feed.get(type(unique_id)) == None:
    #         data_feed[type(unique_id)] = 1
    #     else:
    #         data_feed[type(unique_id)] += 1
    # print("#" * 50)
    # print(data_feed) #We've verified there are no NoneType objects in questions_data
    # Instantiate an instance of each index as an empty dictionary
    eligiblity_index = {}
    revision_streak_index = {}
    subject_question_index = {}
    subject_in_circulation_index = {}
    
    for unique_id, question_object in questions_data.items():
        file_question = {unique_id: question_object}
        # I'm getting a strange bug where the question object morphs into a NoneType object

        # To accomplish a minimal time complexity we will update each function so that the function takes the question object, modifies it, then returns it: For one operation per object
        # Old system scans every question in the list for every property, creating far more operations than necessary
        # # First initialize properties that don't exist with first time values:
        question_object = update_questions.initialize_in_circulation_property(question_object)
        
        question_object = update_questions.initialize_revision_streak_property(question_object)
        
        question_object = update_questions.initialize_last_revised_property(question_object)
        
        question_object = update_questions.initialize_next_revision_due_property(question_object)
        
        question_object = update_questions.initialize_question_media_properties(question_object)
        
        question_object = update_questions.initialize_answer_media_properties(question_object)
        
        question_object = update_questions.initialize_time_between_revisions_property(question_object)
        
        question_object = update_questions.initialize_academic_sources_property(question_object)

        question_object = update_questions.determine_eligibility_of_questions(question_object)

        question_object = update_questions.update_is_module_active_property(question_object, settings_data)
        # Add question to index of eligible questions for the populate_quiz function to use:
        question_object = update_questions.determine_question_id(question_object)
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
        
        
    # Update questions.json
    # Write indices to instance_data/
    # Time sink of .35 seconds to perform all these write operations:
    returned_data = {}
    returned_data["eligibility_index"] = eligiblity_index
    returned_data["revision_streak_index"] = revision_streak_index
    returned_data["questions_by_subject_index"] = subject_question_index
    returned_data["subject_in_circulation_index"] = subject_in_circulation_index
    returned_data["questions_data"] = questions_data
    returned_data["settings_data"] = settings_data
    return returned_data

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

def calculate_question_id(): #Private Function
    '''
    Deprecated, does nothing: is a function stub
    question id is based on the users questions.json
    question id does not exist in the "clean" variant of the question object
    This method prevents duplicate ids, since the id will be determined once the once the user "collects" a given question so will never interfere with others version of the id
    '''
    #FIXME
    # This would be a function to call with the add_question() function
    questions_data = helper.get_question_data()
    # Scan the existing keys in questions_data
    # We call this when we add a question through the interface so we need to [int(i) for i in questions_data.keys() if i.isdigit()] All the file name keys will be filtered out
    # with the filtered list we can generate a numerical id, id is only used for local reference so it does not need to compatible with server side questions
    # Will need to figure out server side id system later
    # What if we generate an id for modules within the write to function that scans the modules and updates the master. Do the id generation check there #FIXME
