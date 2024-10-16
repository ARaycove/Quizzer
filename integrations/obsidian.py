from lib import helper
import json
import obsidiantools
from datetime import datetime, date
import os
import initialize
from module_functions import modules

def scan_directory(vault_path): #Private Function
    # Returns a list(s) of dictionaries
    '''
    takes a list of file_paths as an argument
    scans the vault_path directory and stores the results in two seperate .json
    data.json contains a raw_list of all .md files
    media_paths.json contains the filepaths for all media in the provided directories
    '''
    media_paths = {"file_paths": []}
    concepts = {}
    total_checks = 0
    vault_path = vault_path[0]
    for root, dirs, files in os.walk(vault_path):
        # print(f"Scanning root: {root}")
        # print(files)
        total_checks += 1
        for file in files:
            total_checks += 1
            # If a known text file, store in data.json (for now only .md)
            if helper.is_media(file):
                media_paths["file_paths"].append(os.path.join(root,file))
            elif file.endswith(".md"):
                # Is not media and is a markdown file
                data = obsidiantools.md_utils.get_front_matter(os.path.join(root,file))
                if data == {}:
                    continue
                data["file_name"] = file
                data["file_path"] = os.path.join(root,file)
                for key, value in data.items():
                    total_checks += 1
                    # print(type(date.today()))
                    # print(type(datetime.today()))
                    if type(value) == type(datetime.today()) or type(value) == type(date.today()):
                        data[key] = str(value)
                concepts[file] = data
                    # print(data)
                # If file is not a known document or script file type, it is treated as media, missed checks do not effect integrity of data. Only contribute to storage size bloat

    helper.update_obsidian_media_paths(media_paths)
    print(f"total operations to scan Obsidian Vault: {total_checks}")
    existing_database = concepts
    return existing_database
    


def extract_questions_from_raw_data(existing_database = dict, raw_master_question_list = dict): #Private Function
    '''
    returns questions_list based on any question objects found in data.json
    checks the questions_list and intializes metrics for question objects
    '''  
    for file_name, question_object in existing_database.items():
        # print(f"question object: {i}")
        if question_object.get("type") == "question":
            question_object["object_type"] = "question"
            question_object["is_obsidian_md_question_note"] = True
            if raw_master_question_list.get(file_name) == None: # the question pulled from obsidian does not currently exist in our raw data:
                question_object["id"] = file_name
                raw_master_question_list[file_name] = question_object
            else:
                raw_master_question_list[file_name].update(question_object)
    # with open("instance_data/raw_master_question_list.json", "w+") as f:
    #     json.dump(raw_master_question_list, f, indent=4)
    return raw_master_question_list