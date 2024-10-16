# This module holds functions relating to the updating of settings and configurations
# Currently we need to be able to update the quiz length, and subject weighting for quizzes
import json
import os
from lib import helper
def initialize_subject_settings(settings_data, questions_by_subject_index): #Private Function
    settings_data = helper.get_settings_data()
    # serves as a template for later
    initial_subject_setting = {}
    initial_subject_setting["interest_level"] = 10
    initial_subject_setting["priority"] = 9
    initial_subject_setting["total_questions"] = 0
    initial_subject_setting["num_questions_in_circulation"] = 0
    initial_subject_setting["total_activated_questions"] = 0
    # print(initial_subject_setting)
    for subject in questions_by_subject_index.keys(): # Introduction of index reduced old operation of 3000+ O(n) TC down to around 30 (or the total number of subjects)
        if settings_data.get("subject_settings") == None:
            settings_data["subject_settings"] = {subject:initial_subject_setting}
            # print(f"initialized subject setting for {subject}")
        elif subject not in settings_data["subject_settings"]:
            settings_data["subject_settings"][subject] = initial_subject_setting
            # print(f"initialized subject setting for {subject}")
    return settings_data

def create_first_time_settings_json(): #Private Function
    user_profile_name = helper.get_instance_user_profile()
    settings = {}
    settings["quiz_length"] = 35
    settings["time_between_revisions"] = 1.2
    settings["due_date_sensitivity"] = 12
    settings["vault_path"] = ["enter/path/to/obsidian/vault"]
    settings["desired_daily_questions"] = 135
    if not os.path.exists(f"user_profiles/{user_profile_name}/json_data"):
        os.makedirs(f"user_profiles/{user_profile_name}/json_data")
    with open(f"user_profiles/{user_profile_name}/json_data/settings.json", "w+") as f:
        json.dump(settings, f)

def initialize_settings_json(): #Private Function
    '''creates settings.json if it doesn't exist'''
    try:
        settings = helper.get_settings_data()
        print("settings.json exists")
    except FileNotFoundError:
        print("settings.json not found")
        print("creating settings.json with default values")
        settings = create_first_time_settings_json()
    