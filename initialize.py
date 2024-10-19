import os
import json
from datetime import datetime, timedelta
from lib import helper
import settings_functions.settings as settings
from module_functions import quizzer_tutorial_module
from question_functions import questions
from stats_functions import stats
from integrations import obsidian
import shutil
def generate_first_time_questions_dictionary(user_profile_data: dict) -> dict:
    '''
    Every new user gets the quizzer tutorial as a module added into their profile
    Called by add_new_user(user_name)
    '''
    # Initialize an empty dict
    questions_data = {}
    # Load in the quizzer_tutorial_module
    try:
        quizzer_tutorial = helper.get_module_data("quizzer_tutorial")
    except:
        quizzer_tutorial = quizzer_tutorial_module.generate_quizzer_tutorial(user_profile_data) #FIXME
    # Add the questions in the quizzer_tutorial to the user's questions data field
    
    questions_data.update(quizzer_tutorial["questions"])

    # Send the data back to the add_new_user(user_name) function which calls this
    return questions_data

def generate_first_time_settings_dictionary(user_profile_data:dict) -> dict:
    #FIXME
    settings_data = {}
    return settings_data

def generate_first_time_stats_dictionary(user_profile_data:dict) -> dict:
    #FIXME
    stats_data = {}
    return stats_data


#############################################################################################################
#############################################################################################################
#############################################################################################################
#############################################################################################################
#############################################################################################################
# NOTE OLD PROGRAM, May not need any of these functions
def count_files_in_directory(directory_path): #Private Function
    try:
        if not os.path.isdir(directory_path):
            raise NotADirectoryError(f"The provided path '{directory_path}' is not a directory.")
        items = os.listdir(directory_path)
        files = [item for item in items if os.path.isfile(os.path.join(directory_path, item))]
        return len(files)
    except Exception as e:
        print(f"An error occurred: {e}")
        return 0

def return_file_path(media_file_name): #Private Function
    '''Takes a file name string as input, returns the location of the media'''
    user_profile_name = helper.get_instance_user_profile()
    media_file_name = str(media_file_name)
    with open(f"user_profiles/{user_profile_name}/json_data/obsidian_media_paths.json", "r") as f:
        media_paths = json.load(f)
    for path in media_paths["file_paths"]: # Iterate through the existing media
        if str(path).endswith(media_file_name):
            return path
        		
def move_file_to_media(file_name, module_name): #Private Function #FIXME Now updating this to have media files pushed into the individual user_profile
    user_profile_name = helper.get_instance_user_profile()
    file_path = return_file_path(file_name)
    src = file_path
    #FIXME
    # Need logic that detects what module is using that media and sets the destination to that modules media_files folder
    dst = f"modules/{module_name}/media_files/" # Going to write all media files to respective module folder, for now we'll leave everything in the media_files/ directory
    shutil.copy2(src, dst)
    
def copy_media_into_local_dir(modules_raw): #Private Function
    # This has been updated to now scan the raw module data scanned from obsidian:
    # To add in integrations we need only make sure further integrations pull module_raw_data and update it for each integration involved.
    count_of_expected_str_error = 0
    total_media_files_to_load = 0
    print("START OF MEDIA TRANSFER ERROR LOG")
    for module, question_data in modules_raw.items():
        if type(module) != str or type(question_data) != dict:
            Exception("TypeError Line 53 of initialize.py")
            print(type(module), type(question_data))
            print("Expected type str and type dict")
        for unique_id, qa in question_data.items():
            if qa.get("module_name") == None:
                Exception("module_name was not initialized in question object")
            else:
                module_name = qa.get("module_name")
            if (qa.get("question_image") != None): # and (qa["question_image"] != "") <--- did not solve or reduce errors
                total_media_files_to_load += 1
                try:
                    file_name = str(qa["question_image"])
                    if file_name.startswith("[[") and file_name.endswith("]]"):
                        file_name = file_name[2:-2]
                    move_file_to_media(file_name, module_name)
                except (TypeError, shutil.SameFileError) as e:
                    e = str(e)
                    if e.startswith("expected str"):
                        count_of_expected_str_error += 1
                    else:
                        print(e, file_name)  
            if qa.get("question_audio") != None:
                total_media_files_to_load += 1
                try:
                    file_name = str(qa["question_audio"])
                    # Obsidian integration, scan to see if the file entered is a link, and remove the brackets if so
                    if file_name.startswith("[[") and file_name.endswith("]]"):
                        file_name = file_name[2:-2]
                    move_file_to_media(file_name, module_name)
                except (TypeError, shutil.SameFileError) as e:
                    e = str(e)
                    if e.startswith("expected str"):
                        count_of_expected_str_error += 1
                    else:
                        print(e, file_name)  
            if qa.get("question_video") != None:
                total_media_files_to_load += 1
                try:
                    file_name = str(qa["question_video"])
                    # Obsidian integration, scan to see if the file entered is a link, and remove the brackets if so
                    if file_name.startswith("[[") and file_name.endswith("]]"):
                        file_name = file_name[2:-2]
                    move_file_to_media(file_name, module_name)
                except (TypeError, shutil.SameFileError) as e:
                    e = str(e)
                    if e.startswith("expected str"):
                        count_of_expected_str_error += 1
                    else:
                        print(e, file_name)  
            if qa.get("answer_image") != None:
                total_media_files_to_load += 1
                try:
                    file_name = str(qa["answer_image"])
                    # Obsidian integration, scan to see if the file entered is a link, and remove the brackets if so
                    if file_name.startswith("[[") and file_name.endswith("]]"):
                        file_name = file_name[2:-2]
                    move_file_to_media(file_name, module_name)
                except (TypeError, shutil.SameFileError) as e:
                    e = str(e)
                    if e.startswith("expected str"):
                        count_of_expected_str_error += 1
                    else:
                        print(e, file_name)     
            if qa.get("answer_audio") != None:
                total_media_files_to_load += 1
                try:
                    file_name = str(qa["answer_audio"])
                    # Obsidian integration, scan to see if the file entered is a link, and remove the brackets if so
                    if file_name.startswith("[[") and file_name.endswith("]]"):
                        file_name = file_name[2:-2]
                    move_file_to_media(file_name, module_name)
                except (TypeError, shutil.SameFileError) as e:
                    e = str(e)
                    if e.startswith("expected str"):
                        count_of_expected_str_error += 1
                    else:
                        print(e, file_name)  
            if qa.get("answer_video") != None:
                total_media_files_to_load += 1
                try:
                    file_name = str(qa["answer_video"])
                    # Obsidian integration, scan to see if the file entered is a link, and remove the brackets if so
                    # "[[this value]]"
                    if file_name.startswith("[[") and file_name.endswith("]]"):
                        file_name = file_name[2:-2]
                    move_file_to_media(file_name, module_name)
                except (TypeError, shutil.SameFileError) as e:
                    e = str(e)
                    if e.startswith("expected str"):
                        count_of_expected_str_error += 1
                    else:
                        print(e, file_name)  
    print(f"Error: expected str, bytes or os.PathLike object, not NoneType Error -- Appeared {count_of_expected_str_error} times")      
    print(f"Total Media files detected in questions data is {total_media_files_to_load}")
    print("END OF MEDIA TRANSFER ERROR LOG")

def remove_invalid_question_objects(questions_data):
    count = 0
    question_objects_to_remove = []
    for unique_id, question_object in questions_data.items():
        is_valid = questions.verify_question_object(question_object)
        if is_valid == False:
            question_objects_to_remove.append(unique_id)
    for id in question_objects_to_remove:
        del questions_data[id]
    return questions_data