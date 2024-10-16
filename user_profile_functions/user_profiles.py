import os
import json
# In order to create user profiles we need to implement a login and or user profile selection menu on the frontend.
# However the simple functionality can be written on the backend.
# Get the user_profile_name
# Get the user_profile_password (assuming we are connecting to the server, initially we can add in default_value and leave this as a stub inside the user profile creation function)

def verify_or_generate_user_profile(user_profile_name="default", user_profile_password=None):
    #The input is the name of the user profile and the user_profile_password:
    
    ###############################################################
    # We will use the name to generate a user_profile folder if one doesn't already exist:
    user_profile_name = user_profile_name.lower()
    if not os.path.exists(f"user_profiles/{user_profile_name}"):
        os.makedirs(f"user_profiles/{user_profile_name}")

    elif os.path.exists(f"user_profiles/{user_profile_name}"):
        print(f"user_profiles/{user_profile_name}: directory already exists")

    else:
        print("Something went wrong in user_profiles.py CODE up-1")
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
    return user_profile_name


################################################################################################################################################
################################################################################################################################################
################################################################################################################################################
#NOTE These are old thoughts, just leaving them in, just in case
    # Create a public function call that calls this function with a new user_profile_name
    # Or embed inside the initialization call, so that initialization requires a user_profile_name to be declared, though we will default to default, otherwise:
    
    
    ###############################################################
    # Therefore most functions will need to take a user_profile as an argument, thankfully this should be as simple as updating the helper library so that all get_data and update_data functions take user_profiles as arguments
    # Update all helper functions to take a user_profile_name argument, with "Default" as the default value [X]
    # Update all helper functions to pull data and write data to the location of the user_profile_name/ [X]
    # Update helper functions to use instance_user
    # files that need to move
    # media files #updated functions [X]
    # json_data
    #   obsidian_data.json
    #   obsidian_media_paths.json
    #   questions.json
    #   settings.json
    #   stats.json
    
    ###############################################################
    # We will update the initialization protocol to take user_profile_name as an argument
    # Initialization function would then dump any data into the specified user_profile_name/ folder instead of the backend/ folder
    # Update the initialization function to take user_profile_name="Default" as an argument  

    # This function would get called first inside initialization, so function should return user_profile_name
    # Proper usage would be user_profile_name = verify_or_generate_user_profile(user_profile_name, user_profile_password)
    