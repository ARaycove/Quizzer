
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
    print(f"Value is: {value} and of Type:{type(value)}")
    if value == "true":
        value = True
    elif value == "false":
        value = False
    else:
        valid_status = False

    print(f"Value is: {value} and of Type:{type(value)}")
    return valid_status, value
def update_setting(*keys, value, user_profile_data: dict): # Public Function
    '''
    takes a key (setting) and a new value to be updated
    checks to see if the value is appropriate, then updates settings.json with the new value if appropriate
    * each passed argument is compiled into a dictionary called:
        If you want to change settings["desired_daily_questions"] = 100
            pass in update_settings("desired_daily_questions", 100, user_profile_data)
        To change settings["module_settings"]["module_status"][subject] = False:
            pass in update_settings("module_settings","module_status", subject, False, user_profile_data)
        Alternatively pass in a list
            update_settings(["module_settings","module_status",subject], False, user_profile_data)
    '''
    # First load in settings.json
    settings_data = user_profile_data["settings"]
    valid_status = True
    # The settings are strictly defined, so based on the amount of keys passed we will check the value and see if its appropriate for the key
    if len(keys)    == 1:
        # Will be quiz_length, time_between_revisions, due_date_sensitivity, vault_path, or desired_daily_questions:
        pass
    elif len(keys)  == 2:
        # Will be module_settings["is_module_active_by_default"]
        pass
    elif len(keys)  == 3:
        # Will be subject_settings[subject][interest_level] or subject_settings[subject][priority]
        # Or
        # module_settings["module_status"][subject]
        if keys[1] == "module_status":
            valid_status, value = handle_boolean_settings(key=keys[1], value = value)
            if valid_status == True:
                settings_data["module_settings"]["module_status"][keys[-1]] = value
            # Assuming we've set this to false, now we need to fish out all the questions that belong to that module, out of circulation:
            all_module_data = system_data.get_all_module_data()
            question_list = all_module_data[keys[-1]]["questions"]
            remove_from_in_circ_not_elig    = []
            remove_from_in_circ_elig        = []
            remove_from_reserve_bank        = []
            add_to_deactivated_pile         = []
            add_to_reserve_bank_pile        = []
            if value == False:
                for question_id in question_list:
                    user_question_data = {}
                    if question_id in user_profile_data["questions"]["in_circulation_not_eligible"]:
                        remove_from_in_circ_not_elig.append(question_id)
                        user_question_data = user_profile_data["questions"]["in_circulation_not_eligible"][question_id]
                    elif question_id in user_profile_data["questions"]["in_circulation_is_eligible"]:
                        remove_from_in_circ_elig.append(question_id)
                        user_question_data = user_profile_data["questions"]["in_circulation_is_eligible"][question_id]
                    elif question_id in user_profile_data["questions"]["reserve_bank"]:
                        remove_from_reserve_bank.append(question_id)
                        user_question_data = user_profile_data["questions"]["reserve_bank"][question_id]
                    add_to_deactivated_pile.append({question_id: user_question_data})
                # add the question to the deactivated pile when we deactivate the module
                for dictionary in add_to_deactivated_pile:
                    user_profile_data["questions"]["deactivated"].update(dictionary)
                # Delete the question from all other piles if deactivated
                for question_id in remove_from_in_circ_elig:
                    del user_profile_data["questions"]["in_circulation_is_eligible"][question_id]
                for question_id in remove_from_in_circ_not_elig:
                    del user_profile_data["questions"]["in_circulation_not_eligible"][question_id]
                for question_id in remove_from_reserve_bank:
                    del user_profile_data["questions"]["reserve_bank"][question_id]
            if value == True:
                # If the module is activated it means is was deactivated, all questions for that module should be in the deactivated pile,
                #   Move them to the reserve bank
                for question_id in question_list:
                    user_profile_data["questions"]["reserve_bank"].update(
                        {
                            question_id:
                            user_profile_data["questions"]["deactivated"][question_id]})
                    del user_profile_data["questions"]["deactivated"][question_id]

            # If the value sent through was to activate the module, we need to fish out the questions from the deactivated pile and put them in the reserve pile
            # We know the exact module that got deactivated so we don't need to iterate over everything
    user_profile_data["settings"] = settings_data
    system_data.update_user_profile(user_profile_data)
    return user_profile_data    


    


# def update_system_data(user_profile_data: dict) -> dict:
#     user_profile_data = questions.initialize_and_update_question_properties(user_profile_data)
#     user_profile_data = stats.update_stats(user_profile_data)
#     return user_profile_data