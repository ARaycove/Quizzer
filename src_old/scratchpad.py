# Quizzer Libraries imports
from lib import helper
import system_data
import generate_quiz
import public_functions
# Outside Libraries Import
import json
import re
import requests
import os
from datetime import datetime, timedelta, date
import pandas as pd
import time
import math
import random
import sys
import timeit
import uuid
import types
import random

# load in user data
# settings_data = helper.get_settings_data()
# stats_data = helper.get_stats_data()
# vault_path = settings_data["vault_path"]
# vault_path = vault_path[0]
# print(f"Working in Directory: {vault_path}, {type(vault_path)}")
# generate_test_file()
# obsidian.scan_directory(vault_path)
# obsidian.parse_questions_to_appropriate_modules()
# obsidian.write_obsidian_questions_to_modules()
# modules.update_list_of_modules()
# questions.update_user_questions_with_module_questions()
question_object_data: dict  = system_data.get_question_object_data()
all_module_data: dict       = system_data.get_all_module_data()
user_name                   = "aacra0820@gmail.com"
user_name                   = str(user_name)
user_profile_data: dict     = system_data.get_user_data(user_name)
time_start                  = datetime.now()
######################
def get_list_subjects_without_new_questions(user_profile_data, excluded_subjects = None):
    '''
    Prints out, or otherwise returns a list of all subjects where no new questions are in their profile to introduce to them. If 100 out of 100 questions are in circulation, then the value of the boolean is set to False, if that value is false it will be returned by this function. This is part of the advisory suite of functionality designed with the intention to notify the user of what they are not actively learning new information about.
    The optional parameter excluded_subjects will remove those subjects from the output. For example if you are only interested in STEM major subjects and do not want to be informed when non-STEM related subjects are empty then you will provide the name of those subjects in a list. Later iterations will update the settings function so that the user can toggle the advisor for every given subject when they enter the settings page.
    '''
    miscellaneous_subjects      = ["food"]
    humanities                  = ["anthropology",
                                   "communication",
                                   "greek",
                                   "french",
                                   "religion",
                                   "sociology",
                                   "theology",
                                   "art",
                                   "abrahamic religions",
                                   "aesthetics",
                                   "comparative politics",
                                   "religious studies",
                                   "revolutionary theory",
                                   "scientific history",
                                   "public policy",
                                   "performing arts",
                                   "music",
                                   "international relations",
                                   "feminism",
                                   "economic history",
                                   "determinism_and_free_will",
                                   "history of computer science",
                                   "history of mathematics",
                                   "theoretical computer science",
                                   "theory of computation"
                                   ]
    history_subjects            =   [
                                    "us history",
                                    "european history",
                                    "world history",
                                    "gender",
                                    "journalism_media_studies_and_communication_media_studies",
                                    "labor economics",
                                    "social movements",
                                    
                                    "marxian_economics",
                                    "judaism studies",
                                    "economics",
                                    
    
                                    ]
    computer_science_subjects   = ["cloud computing",
                                   "command_line",
                                   "devops engineering",
                                   "human-computer interaction",
                                   "information technology",
                                   "linux",
                                   "unicode",
                                   "computational complexity theory",
                                   "computer graphics"
                                   ]
    engineering_subjects        = ["engineering",
                                   "electrical engineering"]
    mathematics_subjects        = ["algebra",
                                   "trigonometry",
                                   "geometry",
                                   "discrete mathematics",
                                   "number theory"]
    life_sciences               = [
        "ecology",
        "anatomy",
        "physiology"]
    sciences                    = ["geography",
                                   "geology",
                                   "memory_science",
                                   "physics",
                                   "psychology",
                                   "genetics",
                                   "neuroanatomy",
                                   "psychophysics"]
    excluded_subjects = []
    excluded_subjects.extend(miscellaneous_subjects)
    excluded_subjects.extend(humanities)
    excluded_subjects.extend(history_subjects)
    excluded_subjects.extend(computer_science_subjects)
    excluded_subjects.extend(engineering_subjects)
    excluded_subjects.extend(mathematics_subjects)
    excluded_subjects.extend(life_sciences)
    excluded_subjects.extend(sciences)
    die_roll = 1
    if excluded_subjects == None:
        excluded_subjects = []
    known_subjects = []
    print("What you know now, by subject")
    print("#############################")
    for subject, _ in user_profile_data["settings"]["subject_settings"].items():
        if subject == "miscellaneous":
            continue
        known_subjects.append({"subject": subject,
                               "value": user_profile_data["settings"]["subject_settings"][subject]["num_questions_in_circulation"]})
    known_subjects = sorted(known_subjects, key=lambda x: x["value"], reverse=True)
    for item in known_subjects:
        print(f"{item["subject"]:30}: {item["value"]}")
    print("Subjects not currently being taught")
    print("###################################")
    for subject, subject_data in user_profile_data["settings"]["subject_settings"].items():
        if subject in excluded_subjects:
            continue
        if subject_data["has_available_questions"] == False:
            print(f"{die_roll:5}: {subject}")
        
    number = random.randint(1, die_roll)
    
    print("you rolled to study:",number)
    # Example usage of exclusion of subject list
get_sum = 0
get_sum_all = 0
text_representation = ""
questions_by_date = {}
all_answer_times = []
for question_id, question_object in user_profile_data["questions"]["in_circulation_is_eligible"].items():
    simplified = helper.convert_to_datetime_object(question_object["next_revision_due"])
    simplified = simplified.date()
    simplified = str(simplified)

    # text_representation += f"Question:{question_object_data[question_id]["question_text"]}\n"
    # text_representation += f"Answer:  {question_object_data[question_id]["answer_text"]}\n"

    try:
        questions_by_date[simplified] += 1
    except KeyError:
        questions_by_date[simplified] = 1
    if question_object["revision_streak"] <= 6:
        get_sum += question_object["average_times_shown_per_day"]
    get_sum_all += question_object["average_times_shown_per_day"]
    if question_object.get("answer_times") != None:
        all_answer_times.extend(question_object["answer_times"])
print(f"APD score of eligible questions (RS <= 6):    {get_sum}")
print(f"APD score of eligible questions (all):        {get_sum_all}")
for question_id, question_object in user_profile_data["questions"]["in_circulation_not_eligible"].items():
    simplified = helper.convert_to_datetime_object(question_object["next_revision_due"])
    simplified = simplified.date()
    simplified = str(simplified)
    # text_representation += f"Question:{question_object_data[question_id]["question_text"]}\n"
    # text_representation += f"Answer:  {question_object_data[question_id]["answer_text"]}\n"
    try:
        questions_by_date[simplified] += 1
    except KeyError:
        questions_by_date[simplified] = 1
    if question_object["revision_streak"] <= 6:
        get_sum += question_object["average_times_shown_per_day"]
    get_sum_all += question_object["average_times_shown_per_day"]
    if question_object.get("answer_times") != None:
        all_answer_times.extend(question_object["answer_times"])
print(f"APD score of circulating questions (RS <= 6): {get_sum}")
print(f"APD score of circulating questions (all):     {get_sum_all}")

questions_by_date = helper.sort_dictionary_keys(questions_by_date)
print_list = []
for key, value in questions_by_date.items():
    print_list.append(f"{key:11}:{value}")
print_list.reverse()
for i in print_list:
    print(i)

all_answer_times = [float(i) for i in all_answer_times]
remove_outliers = helper.reject_outliers(all_answer_times)

average_time_to_answer_raw = sum(all_answer_times)/len(all_answer_times)
average_time_to_answer_no_outliers = sum(remove_outliers)/len(remove_outliers)

print(f"Your average answer time is: {average_time_to_answer_raw:.2f} seconds")
num_answered_per_minute = (60/average_time_to_answer_raw)
num_answered_per_hour = num_answered_per_minute * 60
print(f"Average per minute: {num_answered_per_minute:>6.2f} questions per minute")
print(f"Average per hour  : {num_answered_per_hour:>6.2f} questions per hour")
get_list_subjects_without_new_questions(user_profile_data=user_profile_data)
######################

time_end = datetime.now()
print("Time to execute: ",time_end-time_start)

# #FIXME Ensure all media related question object fields reference a mimetype file, if not set them to None value
# def ensure_question_object_mime_type_fields(question_object):
#     if question_object["answer_image"] == "Error":
#         question_object["answer_image"] = None
#     return question_object
# questions_data = helper.get_question_data()
# for unique_id, question_object in questions_data.items():
#     ensure_question_object_mime_type_fields(question_object)

# helper.update_questions_json(questions_data)