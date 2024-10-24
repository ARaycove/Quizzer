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



def determine_eligibility_of_question_object(question_object: dict, settings_data: dict) -> dict:
    '''
    Determines whether or not questions are eligible to be put into 
    circulation and shown to the user
    '''
    print(f"def determine_eligibility_of_question_object(question_object: dict, settings_data: dict) -> dict")
    # Eligibility
    # - The due date is within x amount of hours of the current time
    # - The question has been placed into circulation to be answered
    count = 0
    due_date_sensitivity = settings_data["due_date_sensitivity"]
    next_revision_due_date = question_object["next_revision_due"]
    next_revision_due_date = helper.convert_to_datetime_object(next_revision_due_date)
    
    #First we set the question as ineligible status by default:
    question_object["is_eligible"] = False
    # Decide on factors that Qualify the question in a nested if statement block, Astrociously ugly I know
    # Check the due date, does it fall within the allotted time?
    if next_revision_due_date >= (datetime.now() + timedelta(hours=due_date_sensitivity)):
        pass # The question's due date is in the future and does not fall within the allotted timeframe, therefore the question is not eligible, hit the pass statement then return the object
        print(f"    Due Date does not fall within allotted timeframe, not eligible")
        print(f"    Return object has value of {question_object['is_eligible']}")
    elif question_object["in_circulation"] == False:
        pass # question has not been placed into circulation therefore the question is not eligible, hit the pass statement then return the object
        print(f"    Question is not in circulation, not eligible")
        print(f"    Return object has value of {question_object['is_eligible']}")
    elif question_object["is_module_active"] == False:
        pass # question's module is not active therefore the question is not eligible, hit the pass statement then return the object
        print(f"    Module is not active, not eligible")
        print(f"    Return object has value of {question_object['is_eligible']}")
    else:
        # All conditions met, question is eligible to be shown
        question_object["is_eligible"] = True
        print(f"    All conditions met, question is eligible to be shown")
        print(f"    Return object has value of {question_object['is_eligible']}")
    return question_object



#########################################################
# Calculation functions are grouped below:
#########################################################
# See the initialize_and_update_question_properties to see the master function that calls everything below:
def calculate_average_shown(question_object: dict) -> dict: #Private Function
    print(f"calculate_average_shown(question_object: dict) -> dict")
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
    print(f"    Return object has value of {question_object['average_times_shown_per_day']}")
    return question_object
 
#########################################################
# Initialization functions are grouped below:
#########################################################
def initialize_revision_streak_property(question_object: dict) -> dict:
    print("def initialize_revision_streak_property(question_object: dict) -> dict")
    '''
    If the question is new, initializes the streak to 1
    '''
    if question_object.get("revision_streak") == None:
        print("    Question object did not have revision streak property")
        question_object["revision_streak"] = 1
        print("    Initializing revision_streak to 1")
    return question_object
    
def initialize_last_revised_property(question_object: dict) -> dict:
    '''
    If the question is new, initializes the last_revised to right now
    '''
    print("def initialize_last_revised_property(question_object: dict) -> dict")
    if question_object.get("last_revised") == None:
        question_object["last_revised"] = helper.stringify_date(datetime.now())
    return question_object
    
def initialize_next_revision_due_property(question_object: dict) -> dict:
    '''
    if the question is new, initializes the next_revision_due to right now
    '''
    print("def initialize_next_revision_due_property(question_object: dict) -> dict")
    if question_object.get("next_revision_due") == None:
        question_object["next_revision_due"] = helper.stringify_date(datetime.now() - timedelta(hours=8760)) # This is due immediately and of the highest priority
    return question_object

def initialize_in_circulation_property(question_object: dict, settings_data: dict) -> dict:
    '''
    If the question is new: sets the in_circulation property to False
    New question objects are never in in_circulation until determined to be so
    '''
    print("def initialize_in_circulation_property(question_object: dict, settings_data: dict) -> dict")
    if question_object.get("in_circulation") == None:
        question_object["in_circulation"] = False
    # If a question_object references a module that does not exist, such as the Quizzer Tutorial module, then it will throw a key Error
    # In such cases we should catch the error and set the question to not in circulation
    if question_object["is_module_active"] == False:
        question_object["in_circulation"] = False
    # If for whatever reason question_object still does not have the property, this print statement will throw an error
    print(f"    Return object has in_circulation property of {question_object['in_circulation']}")
    return question_object

def initialize_time_between_revisions_property(question_object: dict, settings_data: dict) -> dict:
    '''
    If the question is New: Initializes the default time_between_revisions to what is determined in the settings
    '''
    print("def initialize_time_between_revisions_property(question_object: dict, settings_data: dict) -> dict")
    if question_object.get("time_between_revisions") == None:
        question_object["time_between_revisions"] = settings_data["time_between_revisions"]
    print(f"    Return object has value of {question_object['time_between_revisions']}")
    return question_object

def update_question_history(question_object:dict, status:str) -> dict:
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

def update_is_module_active_property(question_object: dict, unique_id: str, user_profile_data: dict, question_object_data: dict) -> dict:
    module_name = question_object_data[unique_id]["module_name"]
    activated = user_profile_data["settings"]["module_settings"]["module_status"][module_name]
    question_object["is_module_active"] = activated
    # Unit Test Print Statement
    print(f"def update_questions.update_is_module_active_property:")
    print(f"    Processed: <{module_name}>'s QO: \n    <{unique_id}> \n    with status of <{activated}>")
    return question_object

    
# Note, while updating system to incorporate individual user profiles, each function here relies solely on the helper library to fetch and update data, so changes to helper library
# should update everything system wide