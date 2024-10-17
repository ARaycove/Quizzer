from lib import helper
import math
import datetime
from datetime import (
    date,
    datetime,
    timedelta
)
# AI determination functions
#########################################################
# just function stubs for now
def determine_related_concepts_for_question(question_object=dict):
    '''
    Use AI to determine what concepts are referred to in the question
    '''
    return None



def determine_individual_subjects_for_question(question_object=dict):
    '''
    Use AI to determine what subjects and fields are referred to in the question
    '''
    return ["miscellaneous"]



def determine_question_subjects(question_object):
    '''
    Logic is not implemented, only sets the subject value to miscellaneous if no subject was entered
    '''
    if question_object.get("subject") == None:
        question_object["subject"] = determine_individual_subjects_for_question(question_object)
        return question_object
    else:
        return question_object



def determine_related_concepts(question_object):
    '''
    Logic is not implemented, only sets the related value to None if no related concepts were entered
    '''
    if question_object.get("related") == None:
        question_object["related"] = determine_individual_subjects_for_question(question_object)
        return question_object
    else:
        return question_object



def determine_eligibility_of_questions(question_object):
    '''
    Determines whether or not questions are eligible to be put into 
    circulation and shown to the user
    '''
    # Eligibility
    # - The due date is within x amount of hours of the current time
    # - The question has been placed into circulation to be answered
    count = 0
    settings_data = helper.get_settings_data()
    due_date_sensitivity = settings_data["due_date_sensitivity"]
    next_revision_due_date = question_object["next_revision_due"]
    next_revision_due_date = helper.convert_to_datetime_object(next_revision_due_date)
    
    #First we set the question is in_eligible status by default:
    question_object["is_eligible"] = False
    # Decide on factors that Qualify the question in a nested if statement block, Astrociously ugly I know
    # Check the due date, does it fall within the allotted time?
    if next_revision_due_date <= (datetime.now() + timedelta(hours=due_date_sensitivity)):
        # Check whether or not the question has been placed into circulation
        if question_object["in_circulation"] == True:
            module_name = question_object["module_name"]
            activated = settings_data["is_module_activated"][module_name]
            # Check whether or not the module that the question belongs to is activated in the settings
            if activated == True:
                question_object["is_eligible"] = True
            elif activated == False:
                question_object["in_circulation"] = False
    return question_object



#########################################################
# Calculation functions are grouped below:
#########################################################
# See the initialize_and_update_question_properties to see the master function that calls everything below:
def calculate_average_shown(question_object): #Private Function
    if question_object["revision_streak"] == 1:
        additional_time = (sum([i for i in range(1, 5)])/4)/24 #hours divided by 24 to get days
        
    elif question_object["revision_streak"] <= 3:
        additional_time = (sum([i for i in range(1, 7)])/6)/24
        
    elif question_object["revision_streak"] <= 6:
        additional_time = (sum([i for i in range(1, 9)])/8)/24
        
    elif question_object["revision_streak"] <= 10:
        additional_time = (sum([i for i in range(1, 13)])/12)/24
    
    elif question_object["revision_streak"] <= 15:
        additional_time = (sum([i for i in range(1, 15)])/14)/24
        
    else:
        additional_time = (sum([i for i in range(1, 25)])/24)/24
    # calculation is in days
    average = 1 / (math.pow(question_object["time_between_revisions"], question_object["revision_streak"]) + additional_time)
    question_object["average_times_shown_per_day"] = average
    return question_object
 
#########################################################
# Initialization functions are grouped below:
#########################################################
def initialize_revision_streak_property(question_object):
    '''
    If the question is new, initializes the streak to 1
    '''
    if question_object.get("revision_streak") == None:
        question_object["revision_streak"] = 1
    return question_object
    
def initialize_last_revised_property(question_object):
    '''
    If the question is new, initializes the last_revised to right now
    '''
    if question_object.get("last_revised") == None:
        question_object["last_revised"] = helper.stringify_date(datetime.now())
    return question_object
    
def initialize_next_revision_due_property(question_object):
    '''
    if the question is new, initializes the next_revision_due to right now
    '''
    if question_object.get("next_revision_due") == None:
        question_object["next_revision_due"] = helper.stringify_date(datetime.now() - timedelta(hours=8760)) # This is due immediately and of the highest priority
    return question_object

def initialize_question_media_properties(question_object):
    '''
    If question object is missing properties for question text, image, audio, or video, sets the value to None so the property exists in the object
    '''
    if question_object.get("question_text") == None:
        question_object["question_text"] = None
    if question_object.get("question_image") == None:
        question_object["question_image"] = None
    if question_object.get("question_audio") == None:
        question_object["question_audio"] = None
    if question_object.get("question_video") == None:
        question_object["question_video"] = None
    return question_object
    
def initialize_answer_media_properties(question_object):
    '''
    If question object is missing properties for answer text, image, audio, or video, sets the value to None so the property exists in the object
    '''
    if question_object.get("answer_text") == None:
        question_object["answer_text"] = None
    if question_object.get("answer_image") == None:
        question_object["answer_image"] = None
    if question_object.get("answer_audio") == None:
        question_object["answer_audio"] = None
    if question_object.get("answer_video") == None:
        question_object["answer_video"] = None    
    return question_object

def initialize_in_circulation_property(question_object):
    '''
    If the question is new: sets the in_circulation property to False
    New question objects are never in in_circulation until determined to be so
    '''
    if question_object.get("in_circulation") == None:
        question_object["in_circulation"] = False
    settings_data = helper.get_settings_data()

    # If a question_object references a module that does not exist, such as the Quizzer Tutorial module, then it will throw a key Error
    # In such cases we should catch the error and set the question to not in circulation
    try:
        activated = settings_data["is_module_activated"][question_object["module_name"]]
        if activated == False:
            question_object["in_circulation"] = False
    except KeyError:
        question_object["in_circulation"] = False
    return question_object

def initialize_time_between_revisions_property(question_object):
    '''
    If the question is New: Initializes the default time_between_revisions to what is determined in the settings
    '''
    settings_data = helper.get_settings_data()
    if question_object.get("time_between_revisions") == None:
        question_object["time_between_revisions"] = settings_data["time_between_revisions"]
    return question_object

def initialize_academic_sources_property(question_object):
    '''
    If the question object does not have a "academic_sources" key value pair, initialize an empty list:
    Academic sources will be list of citations, webpages or any other reference to where the information was sourced
    '''
    if question_object.get("academic_sources") == None:
        question_object["academic_sources"] = []
    return question_object


def update_question_history(question_object, status):
    '''
    Creates a history of when a question was answered correctly
    Used in conjunction with in_correct attempt and revision streak value history
    '''
    todays_date = str(date.today())
    # Initialize property if properties don't exists:
    # date is keys, value is number of attempts that day
    if question_object.get("correct_attempt_history") == None:
        question_object["correct_attempt_history"] = {}
    if question_object["correct_attempt_history"].get(todays_date) == None:
        question_object["correct_attempt_history"][todays_date] = 0



    if question_object.get("incorrect_attempt_history") == None:
        question_object["incorrect_attempt_history"] = {}
    if question_object["incorrect_attempt_history"].get(todays_date) == None:
        question_object["incorrect_attempt_history"][todays_date] = 0



    # This is a record of what the revision streak was on that day, but only the final value
    if question_object.get("revision_streak_history") == None:
        question_object["revision_streak_history"] = {}
    question_object["revision_streak_history"][todays_date] = question_object["revision_streak"]


    # Conditional based on status provided
    if status == "correct":
        question_object["correct_attempt_history"][todays_date] += 1
    elif status == "incorrect":
        question_object["incorrect_attempt_history"][todays_date] += 1
    else:
        print("invalid status provided")
    return question_object

def update_is_module_active_property(question_object, settings_data):
    module_name = question_object["module_name"]
    try:
        activated = settings_data["is_module_activated"][module_name]
    except KeyError:
        activated = False
    question_object["is_module_active"] = activated
    return question_object

    
# Note, while updating system to incorporate individual user profiles, each function here relies solely on the helper library to fetch and update data, so changes to helper library
# should update everything system wide