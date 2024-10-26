
# Custom Modules
from lib import helper
import system_data


# Common Libraries
from datetime import datetime
import random

def print_key(key):
    print(f"Key is: {key}")
def handle_integer_settings(key, value):
        '''
        Settings Value should be an integer, validates whether the passed string is of type int
        '''
        valid_status = True
        print_key(key)
        print(f"Value is: {value} and of Type:{type(value)}")
        try:
            value = int(value)
        except ValueError:
            valid_status = False
        try:
            value = float(value)
            value = round(value)
            value = int(value)
        except ValueError:
            valid_status = False
        print(f"Value is: {value} and of Type:{type(value)}")
        return valid_status, value
def handle_boolean_settings(key, value):
    '''
    Ensure the passed value is a boolean
    '''
    valid_status = True
    print_key(key)
    print(f"Value is: {value} and of Type:{type(value)}")
    try:
        value = bool(value)
    except ValueError:
        valid_status = False

    print(f"Value is: {value} and of Type:{type(value)}")
    return valid_status, value
def update_setting(key, value, data:dict, user_profile_data: dict): # Public Function
    '''
    takes a key (setting) and a new value to be updated
    checks to see if the value is appropriate, then updates settings.json with the new value if appropriate
    '''
    # First load in settings.json
    settings_data = user_profile_data["settings"]
    valid_status = True
    key = data["key"]
    full_key = data["full_settings_key"]
    print_key(key)
    print(full_key)
    # Check functions for specific settings:
    # int Value settings:
    ## Quiz Length Settings
    if full_key.endswith("[quiz_length]"): # For now only quiz_length needs to be an integer, ie you can't have a fractional number of questions
        valid_status, value = handle_integer_settings(key, value)
        if valid_status == False:
            return valid_status
        settings_data["quiz_length"] = value
    ## Due Date Sensitivity Setting
    elif full_key.endswith("[due_date_sensitivity]"):
        valid_status, value = handle_integer_settings(key, value)
        if valid_status == False:
            return valid_status
        settings_data["due_date_sensitivity"] = value
    ## Desired Daily Questions Settings
    elif full_key.endswith("[desired_daily_questions]"):
        valid_status, value = handle_integer_settings(key, value)
        if valid_status == False:
            return valid_status
        settings_data["desired_daily_questions"] = value
    ## Activate and Deactive Modules in databanks
    elif full_key.startswith("settings_data[is_module_activated]"):
        valid_status, value = handle_boolean_settings(key, value)
        if valid_status == False:
            return valid_status
        settings_data["is_module_activated"][key] = value
    elif full_key.startswith("settings_data[subject_settings]"):
        valid_status, value = handle_integer_settings(key, value)
        if valid_status == False:
            return valid_status
        # parse out subject from full key
        parsed_subject = str(full_key[len("settings_data[subject_settings]")+1:])
        parsed_subject = parsed_subject[:parsed_subject.find("]")]
        settings_data["subject_settings"][parsed_subject][key] = value

    # value has been validated and mutated into its appropriate type:
    # If the value passed was invalid, thus would cause an error, we will have already returned a valid_status = False code, therefore no udpate will occur
    
    user_profile_data["settings"] = settings_data
    helper.update_user_profile(user_profile_data)    

def update_score(status:str, id:str, user_profile_data: dict): #Public Function
    # A strange bug occured where the id is the old file_name
    check_variable = ""
    questions_data = user_profile_data["questions"]
    # load config.json into memory, I get the feeling this is poor memory management, but it's only 1000 operations.
    question_object = questions_data[id]

    # Alternatively this could have been a seperate function for initializing, both work:
    ############# We Have Three Values to Update ########################################
    check_variable = question_object["revision_streak"]
    print(f"received id value of {id} of type {type(id)}")
    if status == "correct":
        # Sometimes we are able to answer something correctly, even though the projection would say we should have forgotten about it:
        # In such instances we will increment the time_between_revisions so the questions shows less often
        if helper.within_twenty_four_hours(helper.convert_to_datetime_object(question_object["next_revision_due"])) == False:
            print("Task failed successfully: Incrementing time between revisions")
            question_object["time_between_revisions"] += 0.005 # Increment spacing by .5%
        question_object["revision_streak"] = question_object["revision_streak"] + 1
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
    user_profile_data = system_data.increment_questions_answered(user_profile_data)


    check_variable = question_object["last_revised"]
    print(f"This question was last revised on {check_variable}")
    # Convert string json value back to a <class 'datetime.datetime'> type variable so it can be worked with:
    question_object["last_revised"] = helper.convert_to_datetime_object(question_object["last_revised"])
    # dictionary["last_revised"] = datetime.strptime(dictionary["last_revised"], "%Y-%m-%d %H:%M:%S")
    question_object["last_revised"] = datetime.now()
    # Convert value back to a string so it can be written back to the json file
    question_object["last_revised"] = helper.stringify_date(question_object["last_revised"])

    question_object["next_revision_due"] = helper.convert_to_datetime_object(question_object["next_revision_due"])
    # Next revision due is based on the schedule that was outputted from the generate_revision_schedule() function:
    # If question was correct, update according to schedule, otherwise set next due date according to sensitivity settings so question is immediately available again for review regardless of what the user enters
    question_object["next_revision_due"] = system_data.calculate_next_revision_date(status, question_object)
    # Convert value back to a string so it can be written back to the json file
    question_object["next_revision_due"] = helper.stringify_date(question_object["next_revision_due"])
    # dictionary["next_revision_due"] = dictionary["next_revision_due"].strftime("%Y-%m-%d %H:%M:%S")
    check_variable = question_object["next_revision_due"]
    print(f"The next revision is due on {check_variable}")
    # calculate_average_shown()
    # Update question's history stats
    question_object = system_data.update_question_history(question_object, status)
    questions_data[id] = question_object
    user_profile_data["questions"] = questions_data
    


# def update_system_data(user_profile_data: dict) -> dict:
#     user_profile_data = questions.initialize_and_update_question_properties(user_profile_data)
#     user_profile_data = stats.update_stats(user_profile_data)
#     return user_profile_data