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
    