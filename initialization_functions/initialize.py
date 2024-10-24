def verify_system_data_directory():
    import os
    if not os.path.exists("system_data"):
        os.makedirs("system_data")

def initialize_question_object_data_json():
    '''
    Creates the template for which user_profiles can initialize their question list
    '''
    import json
    from module_functions import quizzer_tutorial_module
    question_object_data = {}
    quizzer_tutorial_questions = quizzer_tutorial_module.generate_quizzer_tutorial_question_objects()
    for question_object in quizzer_tutorial_questions:
        unique_id = question_object["id"]
        write_data = {unique_id: question_object}
    question_object_data.update(write_data)
    verify_system_data_directory()
    with open("system_data/question_object_data.json", "w+") as f:
        json.dump(question_object_data, f)

def generate_first_time_questions_dictionary() -> dict:
    '''
    Every new user gets the quizzer tutorial as a module added into their profile  
    Called by add_new_user(user_name)  
    '''
    from lib import helper
    # Initialize an empty dict 
    questions_data = {}
    questions_data["unsorted"] = {}                         # Newly added questions go here
    questions_data["deactivated"] = {}                      # Questions with deactivated modules go here
    questions_data["reserve_bank"] = {}                     # Questions not circulating currently go here -> will get checked by add questions to circulation
    questions_data["in_circulation_not_eligible"] = {}      # Questions placed into circulation but not eligible to be answered go here -> subdivided further by due date to minimize unneccessary operations
    questions_data["in_circulation_is_eligible"] = {}       # Questions placed into circulation AND are eligible to be answered go here -> will be displayed to the user immediately
    # Load in the quizzer_tutorial_module 
    module_data = helper.get_all_module_data()
    # Build first question set based on the questions in the Quizzer Tutorial Module 
    quizzer_tutorial = module_data["Quizzer Tutorial"]
    for unique_id in quizzer_tutorial["questions"]:
        write_data = {unique_id: {}}
        questions_data["unsorted"].update(write_data) #NOTE tutorial questions will immediately go into the unsorted "pile"
    # Send the data back to the add_new_user(user_name) function which calls this 
    return questions_data

def generate_first_time_settings_dictionary(user_profile_data:dict, question_object_data: dict) -> dict:
    from settings_functions import initial_settings_defines
    settings_data = {} 
    settings_data = initial_settings_defines.build_first_time_settings_data(user_profile_data, question_object_data)
    return settings_data

def generate_first_time_stats_dictionary(user_profile_data:dict) -> dict:
    from stats_functions import initial_stats_defines
    stats_data = {}
    stats_data = initial_stats_defines.build_first_time_stats_data(user_profile_data)
    return stats_data

def remove_invalid_question_objects(questions_data: dict, question_object_data: dict) -> dict:
    '''
    takes the questions_data from user_profile_data as input, scans the profile and deletes any questions that do not pass validation
    questions.verify_question_object(question_object) function to ensure the minimal requirements for a question object are met
    '''
    # question_object_data[unique_id] fetches the actual question and answer from the server's master list
    # NOTE master list is shared across all users
    from question_functions import questions
    count = 0
    question_objects_to_remove = []
    for unique_id, question_object in questions_data.items():
        is_valid = questions.verify_question_object(question_object_data[unique_id])
        if is_valid == False:
            question_objects_to_remove.append(unique_id)
    for id in question_objects_to_remove:
        del questions_data[id]
    return questions_data



def sort_questions(user_profile_data: dict, question_object_data: dict):
    '''
    Goes through any questions in the unsorted pile, updates them, then moves them to an appropriate "pile"
    # Questions will be sorted into multiple "piles"
    # Piles:
    # Unsorted: the default place where newly added questions will be put
    # Deactivated:                      If the question's module is deactivated we should place the entry here so we can avoid unneccessary operations
    # NOTE This pile will get scanned whenever module_status changes #FIXME
    # in_circulation - not eligible:    If the question has been placed into circulation but is not currently eligible place it in this pile
    # NOTE circulating but non-eligible questions will be stored under a key by the name of str(datetime.today())
    # in_circulation - is eligible:     If the question has been placed into circulation and is also eligible then place it here, sorted by due_date (where due_date is the key, we need only check items that are within or before today's date) delete empty keys
    '''
    from question_functions import questions
    # when the program starts a function will decide what to put into circulation, that function will put things into circulation, update properties for those questions and then recall this function to sort them out before sending back to user
    questions_data = user_profile_data["questions"]
    questions_to_remove_from_unsorted_pile = [] # list of id's since we can't mutate a dictionary while iterating over it
    for pile_name, pile in questions_data.items():
        if pile_name == "unsorted":
            for unique_id, question_object in pile.items():
                # First update the question properties, ensuring data we are evaluating is accurate
                question_object = questions.update_user_question_stats(question_object, unique_id, user_profile_data, question_object_data)


                # First check if the module that the question belongs to is active, if the module is inactive, then place it in the deactivated pile
                # the deactivated pile will only be checked when a module's activated status changes, that function looks into the deactivated pile and move it's own questions out
                if question_object["is_module_active"] == False:
                    write_data = {unique_id: question_object}
                    questions_data["deactivated"].update(write_data)
                    questions_to_remove_from_unsorted_pile.append(unique_id)

                
                # Now check if the in_circulation property is False, every new question added to Quizzer will not circulate by default so every question whose module is active will go here first
                # Module is active, therefore eligible to be placed into circulation
                elif question_object["in_circulation"] == False:
                    write_data = {unique_id: question_object}
                    questions_data["reserve_bank"].update(write_data)
                    questions_to_remove_from_unsorted_pile.append(unique_id)


                # Now check for the unlikely case where a circulating question got moved to the unsorted pile, move these questions back into the circulation piles
                # Conditions if in_circulation == True
                elif question_object["is_eligible"] == True and question_object["in_circulation"] == True:
                    write_data = {unique_id: question_object}
                    questions_data["in_circulation_is_eligible"].update(write_data)
                    questions_to_remove_from_unsorted_pile.append(unique_id)
                elif question_object["is_eligible"] == False and question_object["in_circulation"] == True:
                    write_data = {unique_id: question_object}
                    questions_data["in_circulation_not_eligible"].update(write_data)
                    questions_to_remove_from_unsorted_pile.append(unique_id)
    
    # Batch delete these id's from the unsorted pile now that they've been moved to the appropriate pile
    for unique_id in questions_to_remove_from_unsorted_pile:
        del questions_data["unsorted"][unique_id]
    return questions_data
def initialize_quizzer(user_profile_name: str) -> None: #Public Function ⁹
    '''
    Main Entry Point for program,
    calls health check functions
    '''
    from lib import helper
    from datetime import datetime
    from module_functions import modules
    from user_profile_functions import user_profiles
    # FIXME Handle Edge Case where user deletes their user_profile:
    # call_server for user data
    # if no user data exists? then user never saved thier data,
    # kick user back to login screen if edge case occurs (Highly unlikely)
    
    # To initialize the program:
    timer_start = datetime.now()
    ###########################################################################################
    user_profiles.verify_user_profile(user_profile_name)


    # Load in user settings data, if the profile is new, then there are default values
    user_profile_data = helper.get_user_data(user_profile_name)

    
    ###########################################################################################
    # External Application Integrations
    obsidian_integration = False
    notion_integration = False

    # Gather a list of modules:
    modules_list = modules.update_list_of_modules()
    # Add in questions that exist in modules but not in the user's questions list
    raw_master_question_list = modules.build_raw_questions()
    user_profile_data = modules.write_module_questions_to_users_questions(raw_master_question_list, user_profile_data)
    # Update the user settings to ensure there is an activation setting for each module that exists in the profile
    # NOTE This allows the user to activate or deactivate modules individually
    user_profile_data = modules.build_activated_setting(modules_list, user_profile_data)
    modules.update_module_profile() # After verifying modules, update metadata for each module
    
    # user_profile_data = public_functions.update_system_data(user_profile_data)

    # End Initialization
    timer_end = datetime.now()
    elapsed_time = timer_end - timer_start
    total_seconds = elapsed_time.total_seconds()
    minutes, seconds = divmod(total_seconds, 60)
    print(f"Success: initialization takes {int(minutes)} minutes and {int(seconds)} seconds.")

#############################################################################################################
#############################################################################################################
#############################################################################################################
#############################################################################################################
#############################################################################################################
# NOTE OLD PROGRAM, May not need any of these functions
# def count_files_in_directory(directory_path): #Private Function
#     import os
#     try:
#         if not os.path.isdir(directory_path):
#             raise NotADirectoryError(f"The provided path '{directory_path}' is not a directory.")
#         items = os.listdir(directory_path)
#         files = [item for item in items if os.path.isfile(os.path.join(directory_path, item))]
#         return len(files)
#     except Exception as e:
#         print(f"An error occurred: {e}")
#         return 0

# def return_file_path(media_file_name): #Private Function
#     '''Takes a file name string as input, returns the location of the media'''
#     import json
#     from lib import helper
#     user_profile_name = helper.get_instance_user_profile()
#     media_file_name = str(media_file_name)
#     with open(f"user_profiles/{user_profile_name}/json_data/obsidian_media_paths.json", "r") as f:
#         media_paths = json.load(f)
#     for path in media_paths["file_paths"]: # Iterate through the existing media
#         if str(path).endswith(media_file_name):
#             return path
        		
# def move_file_to_media(file_name, module_name): #Private Function #FIXME Now updating this to have media files pushed into the individual user_profile
#     from lib import helper
#     import shutil
#     user_profile_name = helper.get_instance_user_profile()
#     file_path = return_file_path(file_name)
#     src = file_path
#     #FIXME
#     # Need logic that detects what module is using that media and sets the destination to that modules media_files folder
#     dst = f"modules/{module_name}/media_files/" # Going to write all media files to respective module folder, for now we'll leave everything in the media_files/ directory
#     shutil.copy2(src, dst)
    
# def copy_media_into_local_dir(modules_raw): #Private Function
#     # This has been updated to now scan the raw module data scanned from obsidian:
#     # To add in integrations we need only make sure further integrations pull module_raw_data and update it for each integration involved.
#     count_of_expected_str_error = 0
#     total_media_files_to_load = 0
#     print("START OF MEDIA TRANSFER ERROR LOG")
#     for module, question_data in modules_raw.items():
#         if type(module) != str or type(question_data) != dict:
#             Exception("TypeError Line 53 of initialize.py")
#             print(type(module), type(question_data))
#             print("Expected type str and type dict")
#         for unique_id, qa in question_data.items():
#             if qa.get("module_name") == None:
#                 Exception("module_name was not initialized in question object")
#             else:
#                 module_name = qa.get("module_name")
#             if (qa.get("question_image") != None): # and (qa["question_image"] != "") <--- did not solve or reduce errors
#                 total_media_files_to_load += 1
#                 try:
#                     file_name = str(qa["question_image"])
#                     if file_name.startswith("[[") and file_name.endswith("]]"):
#                         file_name = file_name[2:-2]
#                     move_file_to_media(file_name, module_name)
#                 except (TypeError, shutil.SameFileError) as e:
#                     e = str(e)
#                     if e.startswith("expected str"):
#                         count_of_expected_str_error += 1
#                     else:
#                         print(e, file_name)  
#             if qa.get("question_audio") != None:
#                 total_media_files_to_load += 1
#                 try:
#                     file_name = str(qa["question_audio"])
#                     # Obsidian integration, scan to see if the file entered is a link, and remove the brackets if so
#                     if file_name.startswith("[[") and file_name.endswith("]]"):
#                         file_name = file_name[2:-2]
#                     move_file_to_media(file_name, module_name)
#                 except (TypeError, shutil.SameFileError) as e:
#                     e = str(e)
#                     if e.startswith("expected str"):
#                         count_of_expected_str_error += 1
#                     else:
#                         print(e, file_name)  
#             if qa.get("question_video") != None:
#                 total_media_files_to_load += 1
#                 try:
#                     file_name = str(qa["question_video"])
#                     # Obsidian integration, scan to see if the file entered is a link, and remove the brackets if so
#                     if file_name.startswith("[[") and file_name.endswith("]]"):
#                         file_name = file_name[2:-2]
#                     move_file_to_media(file_name, module_name)
#                 except (TypeError, shutil.SameFileError) as e:
#                     e = str(e)
#                     if e.startswith("expected str"):
#                         count_of_expected_str_error += 1
#                     else:
#                         print(e, file_name)  
#             if qa.get("answer_image") != None:
#                 total_media_files_to_load += 1
#                 try:
#                     file_name = str(qa["answer_image"])
#                     # Obsidian integration, scan to see if the file entered is a link, and remove the brackets if so
#                     if file_name.startswith("[[") and file_name.endswith("]]"):
#                         file_name = file_name[2:-2]
#                     move_file_to_media(file_name, module_name)
#                 except (TypeError, shutil.SameFileError) as e:
#                     e = str(e)
#                     if e.startswith("expected str"):
#                         count_of_expected_str_error += 1
#                     else:
#                         print(e, file_name)     
#             if qa.get("answer_audio") != None:
#                 total_media_files_to_load += 1
#                 try:
#                     file_name = str(qa["answer_audio"])
#                     # Obsidian integration, scan to see if the file entered is a link, and remove the brackets if so
#                     if file_name.startswith("[[") and file_name.endswith("]]"):
#                         file_name = file_name[2:-2]
#                     move_file_to_media(file_name, module_name)
#                 except (TypeError, shutil.SameFileError) as e:
#                     e = str(e)
#                     if e.startswith("expected str"):
#                         count_of_expected_str_error += 1
#                     else:
#                         print(e, file_name)  
#             if qa.get("answer_video") != None:
#                 total_media_files_to_load += 1
#                 try:
#                     file_name = str(qa["answer_video"])
#                     # Obsidian integration, scan to see if the file entered is a link, and remove the brackets if so
#                     # "[[this value]]"
#                     if file_name.startswith("[[") and file_name.endswith("]]"):
#                         file_name = file_name[2:-2]
#                     move_file_to_media(file_name, module_name)
#                 except (TypeError, shutil.SameFileError) as e:
#                     e = str(e)
#                     if e.startswith("expected str"):
#                         count_of_expected_str_error += 1
#                     else:
#                         print(e, file_name)  
#     print(f"Error: expected str, bytes or os.PathLike object, not NoneType Error -- Appeared {count_of_expected_str_error} times")      
#     print(f"Total Media files detected in questions data is {total_media_files_to_load}")
#     print("END OF MEDIA TRANSFER ERROR LOG")

