
# Custom Modules
from lib import helper
from integrations import obsidian
from stats_functions import update_statistics
from user_profile_functions import user_profiles
from question_functions import update_questions
from module_functions import modules
import quiz_functions
import settings
import questions
import stats
import initialize



# Common Libraries
from datetime import datetime, timedelta
import time
import random
import json

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
def update_setting(key, value, data): # Public Function
    '''
    takes a key (setting) and a new value to be updated
    checks to see if the value is appropriate, then updates settings.json with the new value if appropriate
    '''
    # First load in settings.json
    settings_data = helper.get_settings_data()
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
        settings_data["due_date_sensitivty"] = value
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
    # value has been validated and mutated into its appropriate type:
    # If the value passed was invalid, thus would cause an error, we will have already returned a valid_status = False code, therefore no udpate will occur
    
    helper.update_settings_json(settings_data)    
    
def initialize_quizzer(user_profile_name="default"): #Public Function ⁹
    '''
    Main Entry Point for program,
    calls health check functions
    initializes json data if necessary
    '''
    user_profiles.verify_or_generate_user_profile(user_profile_name)
    # To initialize the program:
    timer_start = datetime.now()
    # Very first check in initialization is to ensure the user profile directories are made,
    # The front end should provide a user profile to work from, if nothing provided (for the sake of testing without a frontend) there is a default user_profile.
    
    
    # NOTE:
    # Ensure these functions initialize based on the above user_profile_name
    # the user_profile_name is stored inside the instance_data/instance_user_profile.json file so we can use the helper library to pull this in any given function
    # Should also make transition to database system smoother
    
    ###########################################################################################
    # NOTE:
    # These function ensure the json file for either the master questions.json, stats.json, or settings.json actually exists
    # These functions do not ensure all properties that should exist do exist. They only aid in avoiding file not found errors:
    print(f"Checking if JSON files exist for user: {user_profile_name}")
    settings.initialize_settings_json() # [ ] updated to write to user_profiles/profile_name
    questions.initialize_questions_json() # [ ] updated to write to user_profiles/profile_name
    stats.initialize_stats_json() # [ ] updated to write to user_profiles/profile_name
    ###########################################################################################
    # Load in user settings data, if the profile is new, then there are default values
    settings_data = helper.get_settings_data()
    
    ###########################################################################################
    # External Application Integrations
    obsidian_integration = False
    notion_integration = False
    # Load Settings Data
    settings_data = helper.get_settings_data()
    questions_data = helper.get_question_data()
    # Build initial master list of every question across all modules
    raw_master_question_list = modules.build_raw_questions()


    # Update master list of questions with any questions extracted from integrations
    #FIXME Test with new user with default value, ensure no errors exists
    existing_database = obsidian.scan_directory(settings_data["vault_path"])
    raw_master_question_list = obsidian.extract_questions_from_raw_data(existing_database, raw_master_question_list)

    # Rewrite the master list into a different data format, (makes it easier for the following function to write to each module)
    modules_list = modules.update_list_of_modules()
    modules_raw = modules.parse_questions_to_appropriate_modules(raw_master_question_list, modules_list)
    # Overwrite existing modules with data in modules_raw (This is a safe operation since the questions contained were derived from the data we are now overwriting)
    # In such a case where a question_object has been modified to where a different module name is defined, the rebuilt data will remove, update, or add as necessary.
    # The key here is that we are compiling all the question objects together, updating those objects with new information, then sorting them back out into desired modules.
    # When a user imports a module, those questions will get pulled and not have a risk of being deleted.
    # Final Note, the operation where we write all questions from modules to the users master question list, we can simply pull raw_master_question_list and update user's questions.json with that data
    questions_data = modules.write_module_questions_to_users_questions_json(raw_master_question_list, questions_data)
    #FIXME create modules.write_user_questions_to_modules() 
    #FIXME This functions purpose would grab questions that exist in questions.json but not within any existing module
    # With that list of questions, we write them to modules (Essentially we could do a for loop over the questions.json O(n) time. and check if the question
    #  is in the raw_master_question_list (if it's not in their we strip out any statistical data from the object then write it to the 
    # raw_master_question_list)) #FIXME Would need a lib.helper function that determines what properties get stripped and what doesn't (pass each 
    # question object to this function and get out a "cleaned" object) The purpose of this "cleaning" is to prevent any user_data from entering the modules.
    # Since the purpose of modules is to be shared, having user_data embedded in the module would overwrite another user's data with someone elses data (Which is not desirable behavior)
    modules_list = modules.update_list_of_modules() # Need to update it twice
    modules.build_activated_setting(modules_list) # This function relys on the above list data
    modules.update_module_profile() # After verifying modules, update metadata for each module
    # Health check question objects
    stats_data = helper.get_stats_data()
    return_data = update_system_data(questions_data, stats_data)
    stats_data = return_data["stats_data"]
    print(return_data.keys())
    subject_question_index = return_data["questions_by_subject_index"]
    
    print(stats_data)
    print(initialize.count_files_in_directory("media_files/"), "media files loaded")
    print("#" * 25)
    # Initialize settings keys (subject keys)
    settings_data = settings.initialize_subject_settings(settings_data,subject_question_index)
    
    # End Initialization
    timer_end = datetime.now()
    elapsed_time = timer_end - timer_start
    total_seconds = elapsed_time.total_seconds()
    minutes, seconds = divmod(total_seconds, 60)
    print(f"Success: initialization takes {int(minutes)} minutes and {int(seconds)} seconds.")

def update_score(status, id): #Public Function
    check_variable = ""
    questions_data = helper.get_question_data()
    stats_data = helper.get_stats_data()
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
    update_statistics.increment_questions_answered(stats_data)


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
    question_object["next_revision_due"] = questions.calculate_next_revision_date(status, question_object)
    # Convert value back to a string so it can be written back to the json file
    question_object["next_revision_due"] = helper.stringify_date(question_object["next_revision_due"])
    # dictionary["next_revision_due"] = dictionary["next_revision_due"].strftime("%Y-%m-%d %H:%M:%S")
    check_variable = question_object["next_revision_due"]
    print(f"The next revision is due on {check_variable}")
    # calculate_average_shown()
    # Update question's history stats
    question_object = update_questions.update_question_history(question_object, status)
    questions_data[id] = question_object
    update_system_data(questions_data, stats_data)
    
def populate_question_list(questions_data, stats_data, settings_data):
    quiz_functions.update_questions_in_circulation() # Start by ensuring questions are put into circulation if we can fit them in the average
    questions_data = helper.get_question_data()
    stats_data = helper.get_stats_data()
    settings_data = helper.get_settings_data()
    returned_data = update_system_data(questions_data, stats_data) # update stats every time we go to get a new list of questions
    eligibility_index = returned_data["eligibility_index"]
    eligibility_index = helper.shuffle_dictionary_keys(eligibility_index)
    questions_data = returned_data["questions_data"]
    stats_data = returned_data["stats_data"]
    settings_data = returned_data["settings_data"]
    # We've already built out an index of all eligible questions, which gets rebuilt when we call update_system_data
    # We the eligible questions are also proportional to interest and priority because of the update_questions_in_circulation function
    # Therefore most of what this function does can be completely stripped away
    # A Quiz Length should still be adhered to, so that every quiz_length num of questions, the system goes to check for new questions to put into circulation, rather than all at once
    quiz_length = settings_data["quiz_length"]
    
    ##################################################
    # filter out questions based on criteria
    sorted_questions = eligibility_index
    
    #############################################
    # Sort question objects by next_revision_due key value
    quiz_length = quiz_functions.ensure_quiz_length(sorted_questions, quiz_length)
    question_list = quiz_functions.select_questions_to_be_returned(sorted_questions, quiz_length)
    # print(f"number of questions chosen: {len(question_list)}")
    if question_list == None:
        sorted_questions = None
    else:
        print(f"Total questions in database : {len(questions_data)}")
        print(f"Number of eligible questions: {len(sorted_questions)}")
        print(f"Number of questions in this round: {quiz_length}")
        random.shuffle(question_list) # ensures there is some level of randomization, so users don't notice this is just a cycling list
        question_list = question_list[::-1] # Reverse the list
        random.shuffle(question_list) # Shuffle it again
        print(f"List of {len(question_list)} questions has been shuffled for pseudorandomness.")
    print(stats_data)
    return question_list

def update_system_data(questions_data, stats_data):
    settings_data = helper.get_settings_data()
    returned_data = questions.initialize_and_update_question_properties(questions_data, settings_data)
    eligiblity_index = returned_data["eligibility_index"]
    revision_streak_index = returned_data["revision_streak_index"]
    subject_question_index = returned_data["questions_by_subject_index"]
    subject_in_circulation_index = returned_data["subject_in_circulation_index"]
    questions_data = returned_data["questions_data"]
    settings_data = returned_data["settings_data"]
    
    returned_data = stats.update_stats(questions_data, stats_data, settings_data, revision_streak_index, eligiblity_index, subject_question_index, subject_in_circulation_index)
    return returned_data