import os
import json
import uuid
from question_functions import questions, update_questions
from settings_functions import settings
from stats_functions import stats
from initialization_functions import initialize
from lib import helper


# In order to create user profiles we need to implement a login and or user profile selection menu on the frontend.
# However the simple functionality can be written on the backend.
# Get the user_profile_name
# Get the user_profile_password (assuming we are connecting to the server, initially we can add in default_value and leave this as a stub inside the user profile creation function)
def verify_user_profiles_directory(user_name) -> None:
    '''
    Ensures the os path for the user_profiles exists
    '''
    if not os.path.exists(f"system_data/user_profiles"):
        os.makedirs("system_data/user_profiles")
    if not os.path.exists(f"system_data/user_profiles/{user_name}"):
        os.makedirs(f"system_data/user_profiles/{user_name}")

def verify_user_dir_doesnt_exist(user_name) -> bool:
    '''
    returns True if the user_profile already exists
    returns False if the user_profile doesn't exist
    '''
    if os.path.exists(f"system_data/user_profiles/{user_name}/{user_name}_data.json") == True:
        print(f"Profile {user_name} already exists")
        return True
    else:
        return False


def add_new_user(user_name: str, question_object_data) -> dict: #Public Function
    '''
    Adds a new user to the local system, returns the default data
    '''
    if user_name == "":
        return None
    user_name = user_name.lower()
    # All data for the user is stored in a master dictionary
    does_exist = verify_user_dir_doesnt_exist(user_name)
    verify_user_profiles_directory(user_name)
    user_profile_data = {}
    if does_exist == False:
        print(f"Creating user profile with name {user_name}")
        user_profile_data["uuid"] = str(generate_unique_id_for_user())
        user_profile_data["user_name"] = user_name
        # These only need to return a predefined dictionary, so nothing is fed into them
        user_profile_data["questions"] = initialize.generate_first_time_questions_dictionary()
        user_profile_data["settings"] = initialize.generate_first_time_settings_dictionary(user_profile_data, question_object_data)
        user_profile_data["stats"] = initialize.generate_first_time_stats_dictionary(user_profile_data)
        for pile_name, pile in user_profile_data["questions"].items():
            for unique_id, question_object in pile.items():
                question_object = questions.update_user_question_stats(question_object, unique_id, user_profile_data, question_object_data)
        helper.update_user_profile(user_profile_data)
    return user_profile_data


def generate_unique_id_for_user() -> uuid:
    got_unique_id = False

    while (got_unique_id == False):
        unique_user_id = uuid.uuid4()
        #FIXME do check to ensure id generated is actually unique
        current_user_id_list = []
        if unique_user_id in current_user_id_list:
            pass
        else:
            got_unique_id = True

    return unique_user_id

def verify_user_profile(user_profile_name: str) -> None:
    #The input is the name of the user profile and the user_profile_password:
    
    ###############################################################
    # We will use the name to generate a user_profile folder if one doesn't already exist:
    user_profile_name = user_profile_name.lower()
    verify_user_profiles_directory(user_profile_name)
    ###############################################################
    # The working profile_name would get assigned to json file so the program knows what user_profile to reference when making calls.
    # This would get changed everytime the program is launched, and would also be able to be changed by a public function to change the working profile
    # This folder would contain any temporary data to be referred to at any given user session
    if not os.path.exists("instance_data"):
        os.makedirs("instance_data")
    out_file = open("instance_data/instance_user_profile.json", "w+") #NOTE Stores the user_profile_name variable in this json file, so other functions can reference which user is currently active
    #NOTE During the big optimization update, this variable could simply become a global CONSTANT variable for the rest of the program to reference instead of performing a read json operation
    json.dump(user_profile_name, out_file, indent=4)
    out_file.close()
    print(f"Current Instance is using profile name: {user_profile_name}")
    #User Profile folder is now created, now we should generate the user_profile.json with appropriate fields
    # if user's user_profile.json exists:
    return user_profile_name
