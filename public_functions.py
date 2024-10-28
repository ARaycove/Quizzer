
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


    


# def update_system_data(user_profile_data: dict) -> dict:
#     user_profile_data = questions.initialize_and_update_question_properties(user_profile_data)
#     user_profile_data = stats.update_stats(user_profile_data)
#     return user_profile_data