import os
import json
from lib import helper
import initialize
from module_functions import module_properties
import questions
# Initial Planning
# Each module will be assigned a folder
# Each module is a class that contains question objects
# At this point OOP has not been implemented, instead a series of functions ensures each dictionary object contains the appropriate properties for the type of object.
# Until I take a proper study of how to implement OOP and do some practice problems and programs this will not be implemented, but is still a planned overhaul
# Obsidian integration needs to dump questions into a default obsidian questions modules
# Questions added through the add_question function needs to dump questions into a default user_default module if a module is not specified.

# We could implement this solely through the add_question function (not yet made)

#FIXME Create the add_question function inside public_functions.py

###########################################################################################################################################################
# Make sure modules are placed inside the backend/modules/ folder #FIXME
# Modules themselves will be stored in the modules/ folder inside the backend/ folder, this will avoid duplication of modules
# This means a user_profile simply needs to point to specific modules in that folder to have them included in their questions.json master file
# storing them altogether also means that all profiles can share and see every module on the system



###########################################################################################################################################################
# Update initialization functions so media files are placed in their appropriate module/media_files/ folder #FIXME
# Update Obsidian integration so scanned questions are stored in a default module if not specified #FIXME
# Media files however, instead of being stored directly in backend/media_files/ will be stored:
# backend/modules/module_name/media_files/
# Doing this ensures media for questions is packaged with the module they are a part of.
# Requires that we update initialization function so that questions scanned from Obsidian are placed into a module instead of questions.json


###########################################################################################################################################################
# Each module will also have a record of file_name: file_path; inside them. #FIXME
# Create a master file in backend/ that contains all the file paths for all media across all modules #FIXME
# master file will be constructed by compiling all the individual file_name: file_path records inside each module

###########################################################################################################################################################
# Need to construct a data structure for a module
# Properties
# module = {
#     "is_a_quizzer_module": True; #Quizzer will check this value and terminate if it equals False, this ensures if the user doesn't import something that isn't a quizzer module
#     "activated": bool;
#     "media_file_record": {"file_name": "file_path"}; #the key is the file_name, so we can search for the file_name using module_name["media_file_record"][file_name] to get the file_path
#     "module_questions": [{question_object}, {question_object}];                                                # Should be more efficient on system resources
    
# } 

###########################################################################################################################################################
#FIXME ID generation functionality
# take a string being the file name
# "."join([ord(i) for i in string if i.isalpha].extend(determine_module_qa_id()))
# last digit is an incremented integer: 001 002 003 004 005 etc.
# use rfind(.) to get index and parse out the end of the string, increment the number and 
#FIXME ID generated here will be the permanent id for that given question object, therefore need to update the generate question_id function in update_questions.py

###########################################################################################################################################################
#FIXME Edit module from within GUI
#FIXME if questions will now be added/removed dynamically from the master_list then where to store the scoring metrics?
# We can't store it in the individual module.
# The question object itself is raw text and doesn't take much data, so we can implement a new property activated: bool; and module_name: "module_question_belongs_to";
#FIXME update determine question eligibility to take into account whether a question is activated or not 
# This way we can keep the scoring metrics inside the individual questions, and if the question is "not activated" then we can just make it invisible inside quizzer altogether


# Two overall phases
# Phase 1:
# Create the system, but don't integrate it with the existing question storage and integration
# So make a compiled_questions.json file to work with leaving the questions.json master untouched.
# Once we have a working module system then we can integrate and merge data (compiled_questions.json(update(questions.json)))
# Phase 2: 
# Optimize and integrate the module systeme so the populate question functionality used our new compiled_questions.json to pull questions
# Update the library so data thats pulled and written to is the new compiled_questions.json instead of the old questions.json

# So how do we get this done?
# Step 1, change the obsidian integration file to write modules/ instead of questions.json
# Initialize_module function is needed,
# check if question object scanned has a module property value, if not module_name == "obsidian_default_module";
# 
# Step 2, Create the add_question function and test it, making sure it calls our initialize_module function
# Let's get started:

# See scratchpad for current iteration
################################################################################################################################
################################################################################################################################
################################################################################################################################
# Two functions are here to define what the initial module data looks like:
# FIXME create a set of verification functions that ensure the data inside a module is of the correct format, similar to what we do for question objects
# SOLVED with a is_quizzer_module boolean

def update_list_of_modules():
    '''
    function scans the modules/ folder and writes instance_data/instance_module_list.json
    This works as an index of all modules detected in the modules folder
    Writes list to json data then returns the list
    '''
    module_list = {}
    for root, dirs, files in os.walk("modules"):
        for file in files:
            if file.endswith("_data.json"):
                module_name = file[:-10]
                module_list[module_name] = os.path.join(root, file)
    with open("instance_data/instance_module_list.json", "w+") as f:
        json.dump(module_list, f, indent=4)
    return module_list

def build_activated_setting(modules_list):
    '''
    Looks up instance_module_list.json and ensures the is_activated setting for each module exists in the user's subject settings.json
    '''
    settings_data = helper.get_settings_data()
    #Ensure is_activated key value pair exists:
    #NOTE Example structure:
    # "is_module_activated": {
    #     "Multiplication Table": true,
    #     "Periodic Table of Elements": true,
    #     "obsidian_default": true,
    #     "Typing Unicode Characters": true,
    #     "Understanding Scale": true,
    #     "Trigonometry": true,
    #     "Python - Lists": true,
    #     "Intro Web Design": false
    # }
    if settings_data.get("is_module_activated") == None:
        settings_data["is_module_activated"] = {} # empty dictionary to be filled later
    for module_name, module_file_path in modules_list.items():
        # If no setting exists for that module, we'll default to activated status. It would seem unlikely that a user would add a module they are not intending to use
        # NOTE But do keep in mind the existence of black swans #FIXME ask for external advice before fully committing to this default, or create a setting so the user can decide for themselves
        if settings_data["is_module_activated"].get(module_name) == None:
            settings_data["is_module_activated"][module_name] = True
        # If the module name already exists in here, then do nothing
        elif settings_data["is_module_activated"].get(module_name) != None:
            pass
        else:
            raise Exception("is_module_activated setting both exists and doesn't exist. How?")
    helper.update_settings_json(settings_data)
            
def build_raw_questions():
    '''
    Scans each module that currently exists and builds a dictionary of the format:
    {
        unique_id: question_object,
        unique_id: question_object,
        unique_id: question_object,
        unique_id: question_object
    }
    Serves as a master list of questions
    This is an initialization function
    '''
    # First fetch the list of module names from instance data
    module_list = update_list_of_modules()
    # initialize master_list as variable
    raw_master_question_list = {}
    # Extract question objects from every module inside the modules folder
    for module_name in module_list:
        module_data = helper.get_module_data(module_name)
        module_question_list = module_data["questions"]
        # Notice we're pulling an id already, but we're calculating it down below
        for unique_id, question_object in module_question_list.items():
            write_data = {unique_id: question_object}
            # Define the question_id here:
            #NOTE This recalculates the id on initialization, a second "redundant" call (in the update_system function) ensures that if id is deleted mid program that it will "regenerate"
            question_object = questions.calculate_question_id(question_object)
            # if question_object.get("file_name") != None: # file_name is used for Obsidian md integration
            #     question_object["id"] = question_object["file_name"]
            # Before writing to the raw_master_list, we need to verify the question_object is valid:
            is_valid = questions.verify_question_object(question_object)
            if is_valid == True:
                raw_master_question_list.update(write_data)
    # return the master_question_list (this way we can avoid future read operations)
    



    return raw_master_question_list
        


def defines_initial_module_data(module_name=str):
    initial_module_data = {}
    # Series of initial properties
    if module_name == "obsidian_default":
        initial_module_data["module_name"] = "Obsidian Default Module"
        initial_module_data["description"] = "This module means no module was defined in the yaml property, quizzer by default creates this module to store such questions"
    else:
        initial_module_data["module_name"] = module_name
        initial_module_data["description"] = "No Description Provided"
    
    initial_module_data["is_a_quizzer_module"] = True
    initial_module_data["primary_subject"] = "" #FIXME gather all questions in the module, the subject name that appears the most is the primary subject
    initial_module_data["all_subjects"] = [] #FIXME gather all questions in the module, result is a set of all subjects mentioned
    initial_module_data["concepts_covered"] = [] #FIXME gather all questions in the module, create a set of all items in the related fields
    initial_module_data["questions"] = {}
    # initial_module_data["activated"] = False # modules deactivated by default when added, modules to be actived by users not within the module itself
    # media_file_record and module_questions will be added later with different functions
    
    
    # This is a return statement :'( <--- this is a crying face in case you didn't get the joke.
    return initial_module_data

def defines_initial_module_mindmap_data():
    initial_module_mindmap_data = {}
    # Series of initial properties:
    
    # This is a return statement :P <-- this is a face with a tongue sticking out :)
    return initial_module_mindmap_data



################################################################################################################################
def verify_and_initialize_module(module_name):
    # First ensure the module folder itself exists:
    if not os.path.exists(f"modules/"):
        os.makedirs(f"modules/")
    # Second ensure the folder for that module exists:
    if not os.path.exists(f"modules/{module_name}"):
        os.makedirs(f"modules/{module_name}")
    # Third ensure the media_files/ folder exists for that module
    if not os.path.exists(f"modules/{module_name}/media_files/"):
        os.makedirs(f"modules/{module_name}/media_files")
    # Fourth ensure the module_name_data.json exists
    # module_name_data.json defines the module and the comprised data for that module
    try:
        with open(f"modules/{module_name}/{module_name}_data.json", "r"):
            # print(f"Module: {module_name} exists")
            pass
    except:
        with open(f"modules/{module_name}/{module_name}_data.json", "x") as f:
            print(f"Module: {module_name} does not exist; initializing {module_name}_data.json")
            module_name_data = defines_initial_module_data(module_name)
        try:
            with open(f"modules/{module_name}/{module_name}_data.json", "w") as f:
                json.dump(module_name_data, f, indent=4)
        except TypeError:
            # print("This threw a type error, because of the index argument, but it still worked?") That's why the try except was placed around the write_to function
            pass
    # Fourth ensure the module_name_mindmap.json exists:
    # module_name_mindmap.json is the individual mindmap data for that module for helping determine relations of ideas
    try:
        with open(f"modules/{module_name}/{module_name}_mindmap.json", "r"):
            # print(f"Module: {module_name} exists")
            pass
    except:
        with open(f"modules/{module_name}/{module_name}_mindmap.json", "x") as f:
            print(f"Module: {module_name} does not exist; initializing {module_name}_data.json")
            module_name_mindmap = defines_initial_module_mindmap_data()
        try:
            with open(f"modules/{module_name}/{module_name}_mindmap.json", "w") as f:
                json.dump(module_name_mindmap, f, index=4)
        except TypeError:
            # print("This threw a type error, because of the index argument, but it still worked?") That's why the try except was placed around the write_to function
            pass


def check_existing_questions_against_modules():
    '''
    Reads questions.json, and each existing corresponding module in quizzer
    '''
    #FIXME WIP
    questions_data = helper.get_question_data()
    no_existing_module_data = True
    module_list = []
    # sort out questions_data into a different format
    modules_raw = {}
    existing_module_data = {}     
    for unique_id, question in questions_data.items():
        if question.get("module_name") == None:
            # Initialize question module to default_module
            question["module_name"] = "Uncategorized Module"
        module_name = question["module_name"]
        if question["module_name"] not in module_list:
            # We start with an empty list, add module names to this list as we come across them
            # If we've already seen the module name then we don't need to do anything.
            # Initialize that module, then add the question to it
            verify_and_initialize_module(question["module_name"])
            module_list.append(module_name)
            modules_raw[module_name] = {} # Initialize key with a dictionary value to update questions to
        write_data = {unique_id: question}
        modules_raw[module_name].update(write_data)
    # Now that questions are sorted into their modules, we can check them against existing modules more efficiently
    for module_name in module_list:
        # Load in the existing data for that module
        try:
            existing_module = helper.get_module_data(module_name)
            write_data = {module_name: existing_module}
            existing_module_data.update(write_data)
        except:
            print(f"No module by name: {module_name}")
            
    for unique_id, question in questions_data.items():
        questions_marked_for_deletion = []
        questions_marked_for_addition = []

        module_name = question["module_name"]
        # Check if question is an integration, if so skip
        # existing_module_data[module_name]["questions"]

        if question.get("is_obsidian_md_question_note") == True:
            continue
        update_data = {unique_id: question}
        if existing_module_data[module_name].get("questions") == {}:
            existing_module_data[module_name]["questions"] = modules_raw[module_name]
        elif existing_module_data[module_name].get("questions") != {}: # Meaning there is existing data to work with:
            # If question already exists where it belongs then we just update it
            if unique_id in existing_module_data[module_name]["questions"]:
                existing_module_data[module_name]["questions"].update(update_data)
            # If the question is not in there then we add it
            elif unique_id not in existing_module_data[module_name]["questions"]:
                existing_module_data[module_name]["questions"].update(update_data)
    for unique_id, question in existing_module_data[module_name]["questions"].items():
        if question.get("is_obsidian_md_question_note") == True:
            continue
        elif unique_id in questions_data:
            pass
        elif unique_id not in questions_data:
            questions_marked_for_deletion.append(unique_id)
            
            
            
    for unique_id in questions_marked_for_deletion:
        del existing_module_data[module_name]["questions"][unique_id]
        
        
        
    for module_name, existing_module in existing_module_data.items():
        helper.update_module_data(existing_module)
        

def parse_questions_to_appropriate_modules(raw_master_question_list, modules_list):
    # How this will work,
    # Iterate over every question in the list
    total_questions = 0
    total_dictionaries = 0
    how_many_x = 0
    how_many_y = 0
    modules_raw = {}
    # Loop over the master list of questions and map out modules_raw where:
    # {
    # module_name: {
    #               unique_id: question_object,
    #               unique_id: question_object
    #               },
    # module_name: {
    #               unique_id: question_object,
    #               unique_id: question_object
    #               }
    # }
    for unique_id, question in raw_master_question_list.items():
        total_dictionaries += 1
        # Meaning there are objects that are not questions residing inside this list of data. So we will first check and make sure the object is a question before proceeding:
        # Initialize and build out module json objects
        if question.get("module_name") == None or question.get("module_name") == "obsidian_default": # No module defined
            how_many_x += 1
            module_name = "obsidian_default"
            verify_and_initialize_module(module_name)
            question["module_name"] = module_name
            if modules_raw.get(module_name) == None:
                modules_raw[module_name] = {}
            modules_raw[module_name].update({unique_id: question})
        else: # A module is defined
            how_many_y += 1
            module_name = question.get("module_name")
            verify_and_initialize_module(module_name)
            if modules_raw.get(module_name) == None:
                modules_raw[module_name] = {}
            modules_raw[module_name].update({unique_id: question})
            # Move any media files referenced in the question objects into the module_name/media_files/ folder
            # For this the move media to local dir function has been updated to scan the modules data instead
            # That function is inherently a part of integrations, since a manually added question would already dump media to its appropriate spot without need of checks
    print(f"Total Questions Scanned: {total_questions}")
    print(f"Total dictionary items scanned: {total_dictionaries}")
    print(f"Call no module defined: {how_many_x}, Call module pre-defined: {how_many_y}")
    # Unit Test
    if total_questions != (how_many_x) + (how_many_y):
        Exception("Error obsidian integration, Obsidian vault not being scanned correctly")
    # There may be modules in modules_list that are not in modules_raw:
    for module_name in modules_list:
        if module_name not in modules_raw:
            modules_raw[module_name] = {} # add the module_name with an empty dictionary, now when we iterated over modules_raw, we will delete any question_objects remaining in empty modules
    for module_name, questions_list in modules_raw.items(): # Not every double for loop is O(n²)
        module_data = helper.get_module_data(module_name)
        # we are going to completely overwrite the existing module's questions property with the updated properties
        module_data["questions"] = questions_list
        helper.update_module_data(module_data)
    # Dump the data, then fetch the media and transfer it.
    initialize.copy_media_into_local_dir(modules_raw) # This functions scans the instance_module_raw_data.json dump, could be last since it's only ensuring the modules have the media required inside themselves
    print("Finished Verifying Modules")
    # helper.throw_exception()
    return modules_raw

def write_module_questions_to_users_questions_json(raw_master_question_list, questions_data):
    '''
    receives a master list of questions derived from existing modules and any possible integrations
    updates the users questions.json with the new data
    '''
    ticker = 0
    for unique_id, question_object in raw_master_question_list.items():
        write_data = {unique_id: question_object}
        # if the question object in the raw_master_question_list is not in the user's questions.json master file at all, then we'll add it.
        if unique_id not in questions_data:
            questions_data[unique_id] = question_object
        # Otherwise we'll update the existing object with the new data, any edits made to question objects in the modules will reflect in the user's questions.json
        else:
            questions_data[unique_id].update(question_object) #NOTE if you omit the above if statement, a KeyError will result if raw data has objects that the user's questions.json does not

    helper.update_questions_json(questions_data)
    return questions_data


def update_module_profile():
    '''
    Master function to house all functions related to updated and verifying metadata of each module, not including what questions are contained within
    '''
    module_list = update_list_of_modules()
    for module_name in module_list:
        module_data = helper.get_module_data(module_name)
        module_data = module_properties.update_module_primary_subject_property(module_data)
        module_data = module_properties.update_module_all_subjects_property(module_data)
        module_data = module_properties.update_module_all_concepts_property(module_data)
        helper.update_module_data(module_data)

def update_modules_with_proper_ids():
    '''
    Updates the old system of id's from Obsidian with the new encoded id system, this ensures all id's are unique and more readable by the machine
    '''
    module_list = update_list_of_modules()
    for module_name in module_list:
        new_questions_list = {}
        module_data = helper.get_module_data(module_name)
        module_question_list = module_data["questions"]
        # Notice we're pulling an id already, but we're calculating it down below
        for unique_id, question_object in module_question_list.items():
            question_object = questions.calculate_question_id(question_object) #NOTE if the question id has already been calculated, then it will remain the same
            # The question object now has a new id
            # Update the unique_id with the new id
            unique_id = question_object["id"] #NOTE Since the question_object["id"] doesn't change, this line will not change either, but does ensure the unique id key always matches the question["id"] value
            write_data = {unique_id: question_object}
            new_questions_list.update(write_data) # add the updated pair to a new set
        # We now have the original module data
        # We now have a new set to replace the old set with:
        module_data["questions"] = new_questions_list
        # Update made within function
        # Now update the module folder itself
        helper.update_module_data(module_data)
        #NOTE in the future, adds and edits will need to be made both to the module itself and to the users questions.json