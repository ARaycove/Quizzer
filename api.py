# Installation of quizzer:
# pip3 install starlette
# pip3 install uvicorn
# pip install "uvicorn[standard]"
# pip install pydantic
# pip install fastapi
# ALL FUNCTIONS HERE ARE CONSIDERED PUBLIC FUNCTIONS
#How to run the server component
from typing import Union
from fastapi import FastAPI
import json
import uvicorn
from lib import helper
import public_functions
import settings
import stats
from user_profile_functions import user_profiles
import os
import time
#########################################################
# Planned features
#FIXME Would need a script that restores the current user data in case of corruption with the most recent, valid, backup copy

#FIXME Develop a Front-End
##FIXME Menu page that displays all subjects divided into two columns, left column displays subjects with remaining questions, right column displays subjects with no remaining questions to add
##NOTE Purpose of this is so the user can, at a glance, decide what they are going to study or work on. What should I add in.
##FIXME in the display, to the right of the text should be a stat displaying x/y. Where x is the number of questions in circulation, and y is the total activated questions. If x == y then Quizzer is no longer introducing any new information



#FIXME Package the program and ship it for the first time:
#################################################################################

#FIXME The Big MindMap Function Updatre (Much further down the line, graph the relations between concepts)
#########################################################




# To start API
app = FastAPI()
# def launch_api():
#     subprocess.run([])
#     uvicorn.run("api:app", host="127.0.0.1", port=8000)
#############################################################################
#############################################################################
#############################################################################
# these two functions are just for example/reference
@app.get("/")
def read_root():
	data = {"Hello": "I see you reading me, this is the root directory of the api server!"}
	return data

# example (I'll be reading from this example for the update score call)
@app.get("/items/{item_id}")
def read_item(item_id: int, q: Union[str, None] = None):
    # Try and get an Ooga booga! from the api server, for practice.
	if q == "test" and item_id == 5:
		response = "Ooga booga!"
	else:
		response = "try again"
	return response
#############################################################################
#############################################################################
#############################################################################
@app.get("/populate_quiz")
def return_question_list():
    '''
    returns a list of questions to be presented to the user
    '''
    questions_data = helper.get_question_data()
    stats_data = helper.get_stats_data()
    settings_data = helper.get_settings_data()
    question_list = public_functions.populate_question_list(questions_data, stats_data, settings_data)
    return question_list

#FIXME add in a add_question_function and api_call
@app.get("/add_question")
def add_question():
     '''
     Generates a question object based on the provided input (This is just the base properties not the statistics that are tied to each object)
     Initializes a module for that question object and adds the question to that module (If the module already exists, then it just adds the question object to the existing module)
     3rd, adds the question object to users questions.json
     In short, creates questions, adds to {module_name}_data.json and questions.json
     '''
    # Step 1 (Generate a question object)

    # Step 2 (Check the module_name for that object, initialize a module with that name if it doesn't exist)
    
    # Step 3 (Add the question object to the module with module_name)

    # Step 4 (Add the question object to the users questions.json)

#FIXME add in edit_question() function and api call
@app.get("/edit_question")
def edit_question(file_name):
     '''
     takes a file_name, and other base question properties, finds the question_object with that unique_id and edits the question inside that module
     '''
# function stub


@app.get("/update_score/{status, id}")
def question_answer_update_score(status: str, id: str):
    '''
    Use to update the score for the question
    options are "correct" or "incorrect"
    '''
    questions_data = helper.get_question_data()
    stats_data = helper.get_stats_data()
    print(f"Received id value of: {id}")
    response = f"updated question with id {id}"
    encoded_val = id
    decoded_val = encoded_val.split(".")
    decoded_val = [chr(int(i)) for i in decoded_val]
    decoded_val = "".join(decoded_val)
    id = decoded_val
    if status == "correct":
        public_functions.update_score(status, id, questions_data, stats_data)
    elif status == "incorrect":
        public_functions.update_score(status, id, questions_data, stats_data)
    else:
        response = "Please enter a valid status, 'correct' or 'incorrect'"
    stats_data = helper.get_stats_data()
    questions_data = helper.get_question_data()
    # Stat feed to console:
    print("#" * 25)
    print("Stats Feed")
    for key, value in stats_data.items():
        print(f"{key:50}|{value}")
    print("End of Stats Feed")
    print("#" * 25)
    return response
    

@app.get("/update_setting/{key, value}")
def update_a_setting_value(key=str, value=str):
    '''
    Used to update a value located in the settings.json file
    Please note I did not actually use this in the current front-end version
    '''
    print(key)
    print(value)
    response = public_functions.update_setting(key, value)
    return response

@app.get("/initialize_quizzer/{user, password}")
def initialization(user: str, password: str): # This function will contain all the initialization functions from various modules:
    '''
    calls the initialization process
    Needs to be called on application startup
    '''
    print(f"Received Data for Initialization:\n USER: {user} \n PASSWORD: {password}")
    print("#" * 50)
    print(f"Initializing user profile name: {user}") 
    user_profiles.verify_or_generate_user_profile(user, user_profile_password=None)
    public_functions.initialize_quizzer(user)
    
    
    
#############################################################################
#############################################################################
#############################################################################
# API Calls used to get the existing user data for the front end to work with
@app.get("/get_stats_data")
def get_stats_data_api():
    stats_data = helper.get_stats_data()
    return stats_data

@app.get("/get_settings_data")
def get_settings_data_api():
    settings_data = helper.get_settings_data()
    return settings_data

@app.get("/get_question_data")
def get_question_data_api():
    question_data = helper.get_question_data()
    return question_data

##########################################################################################