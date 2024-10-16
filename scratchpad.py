import quiz_functions
import questions
import settings
import stats
import initialize
from lib import helper
from question_functions import update_questions
from user_profile_functions import user_profiles
from integrations import obsidian
from module_functions import modules
from stats_functions import update_statistics
import public_functions
import json
import re
import yaml
import requests
import os
from datetime import datetime, timedelta, date
import math
import random
import stdio
import sys
import timeit
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

time_start = datetime.now()
######################
questions_data = helper.get_question_data()
for unique_id, qa in questions_data.items():
    if qa.get("question_image") != None:
        source = helper.get_absolute_media_path(qa["question_image"], qa)
        print(source)
######################
time_end = datetime.now()
print(time_end-time_start)

# #FIXME Ensure all media related question object fields reference a mimetype file, if not set them to None value
# def ensure_question_object_mime_type_fields(question_object):
#     if question_object["answer_image"] == "Error":
#         question_object["answer_image"] = None
#     return question_object
# questions_data = helper.get_question_data()
# for unique_id, question_object in questions_data.items():
#     ensure_question_object_mime_type_fields(question_object)

# helper.update_questions_json(questions_data)