from lib import helper
def build_subject_settings(user_profile_data: dict, question_object_data) -> dict: #Private Function
    '''
    Builds or rebuilds the subject settings for the specific user
    '''
    print("def settings.build_subject_settings(user_profile_data: dict, question_object_data) -> dict")
    subject_settings = {}
    # serves as a template for later
    initial_subject_setting = {}
    initial_subject_setting["interest_level"] = 10
    initial_subject_setting["priority"] = 9
    initial_subject_setting["total_questions"] = 0
    initial_subject_setting["num_questions_in_circulation"] = 0
    initial_subject_setting["total_activated_questions"] = 0
    # print(initial_subject_setting)
    # Iterate over every question id contained in the user's 
    for pile_name, pile in user_profile_data["questions"].items():
        # Get all the subjects mentioned in each question
        for unique_id, question_object in pile.items():
            subject_list = question_object_data[unique_id]["subject"]
            for subject in subject_list:
                if subject not in subject_settings:
                    subject_settings[subject] = initial_subject_setting
                    # Tally up the questions that are in_circulation
                    if question_object.get("in_circulation") == True:
                        subject_settings[subject]["num_questions_in_circulation"] += 1
                    # Build an index of user questions sorted by subject
                    subject_settings[subject]["questions"] = []
                    subject_settings[subject]["questions"].append(unique_id)
                    # Tally Total questions
                    subject_settings[subject]["total_questions"] += 1
                    # Tally Total activated questions
                    if question_object.get("is_module_active") == True:
                        subject_settings[subject]["total_activated_questions"] += 1
                else:
                    subject_settings[subject]["questions"].append(unique_id)
                    if question_object.get("in_circulation") == True:
                        subject_settings[subject]["num_questions_in_circulation"] += 1
                    subject_settings[subject]["total_questions"] += 1
                    if question_object.get("is_module_active") == True:
                        subject_settings[subject]["total_activated_questions"] += 1

    print("    Determining if subjects has available questions")
    for subject in subject_settings:
        if subject_settings[subject]["total_activated_questions"] == subject_settings[subject]["num_questions_in_circulation"]:
            subject_settings[subject]["has_available_questions"] = False
        else:
            subject_settings[subject]["has_available_questions"] = True
        # print(f"{subject.title():25} has {in_circulation_count:5}/{total_count:<5} currently in circulation")
    subject_settings = helper.sort_dictionary_keys(subject_settings)
    print()
    print(f"    The user's subject settings are now:")
    for key, value in subject_settings.items():
        print(f"    {key:50}: {value}")
    return subject_settings


def build_module_settings(user_profile_data: dict, question_object_data: dict) -> dict:
    # First check if we've already built module_settings for this user, since we will reuse this function for subsequent
    print()
    print("def settings.build_module_settings(user_profile_data:dict, question_object_data: dict) -> dict") 
    if user_profile_data.get("module_settings") != None:
        module_settings = user_profile_data["module_settings"]
    else:
        module_settings = {}
        module_settings["is_module_active_by_default"] = True
        module_settings["module_status"] = {} # {module_name: bool}
    default_status = module_settings["is_module_active_by_default"]
    # Iterate over every question id and add the module_name to module_status with the default status of ["is_module_active_by_default"]
    for pile_name, pile in user_profile_data["questions"].items():
        if pile_name != "unsorted": #Only scan through newly added questions
            continue
        for unique_id, question_object in pile.items():
            module_name = question_object_data[unique_id]["module_name"]
            # Only add to list, never delete from it
            if module_name not in module_settings["module_status"]:
                module_settings["module_status"][module_name] = default_status
    
    return module_settings
    