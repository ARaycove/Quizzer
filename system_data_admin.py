import os
import json

def verify_system_data_directory():
    if not os.path.exists("system_data"):
        os.makedirs("system_data")

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
    
