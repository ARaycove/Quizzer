import system_data
import os
import json
# def generate_test_file():
#     questions_data = helper.get_question_data()
#     new_structure = {}
#     for question in questions_data:
#         del question["id"]
#         question["file_name"] = question["file_name"][1:]
#         new_structure[question["file_name"]] = question
#     with open("modules_question_test.json", "w+") as f:
#         json.dump(new_structure, f, indent=4)

# def get_subjects(): #Private Function
#     '''returns a set of subjects based on the subject key in questions.json
#     lets you know all the subjects that exist in questions.json'''
#     settings_data = helper.get_settings_data()
#     subject_set = set([])
#     for subject in settings_data["subject_settings"]:
#         subject_set.add(subject)
#     return subject_set

def print_all_hexidecimal_characters():
    '''
    Prints out a feed of all hexidecimal characters, 50 per line
    '''
    var = 0 
    for i in range(5000):
        print(chr(i), end="")
        var += 1
        if var >= 50:
            print()
            var = 0

def verify_user_profile(user_profile_name: str) -> None:
    #The input is the name of the user profile and the user_profile_password:
    
    ###############################################################
    # We will use the name to generate a user_profile folder if one doesn't already exist:
    user_profile_name = user_profile_name.lower()
    system_data.verify_user_profiles_directory(user_profile_name)
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

def ensure_quiz_length(sorted_questions, quiz_length): #Private Function
    '''
    function provides that the attempted number of questions to be populated into the quiz is <= the number of questions available for selection:
    '''
    if len(sorted_questions) < quiz_length:
        quiz_length = len(sorted_questions)
    if quiz_length <= 0:
        return None
    return quiz_length



##################################################################
def get_number_of_revision_streak_one_questions(sorted_questions):#Private Function
    num_questions = 0
    for unique_id, question in sorted_questions.items():
        if question["revision_streak"] == 1:
            num_questions += 1
    return num_questions
# selection algorithm



##################################################################
def select_questions_to_be_returned(sorted_questions, quiz_length): #Private Function
## questions filled first, if revision streak is 1, always fill these
    question_list = []
    if len(sorted_questions) == 0:
        return []
    # Very simplified logic, since we already determined proportions and eligiblity all we're going to do is as questions from sorted_questions until we meet the quiz length
    for unique_id, question in sorted_questions.items():
        question_list.append(question)
        if len(question_list) >= quiz_length:
            return question_list
        
def update_module_data(module_data: dict) -> None:
    '''
    feed this function the data to be written back to the modules/ folder
    each module has a module name property, so you can't fuck up and feed in the wrong module name
    Just provide the data you need to write back and this function figures out where it belongs
    '''
    import json
    module_name = module_data["module_name"]
    # Patch fix, lol
    if module_name == "Obsidian Default Module":
        module_name = "obsidian_default"
    with open(f"modules/{module_name}/{module_name}_data.json", "w+") as f:
        json.dump(module_data, f, indent=4)

def update_user_question_stats(user_profile_data: dict) -> None:
    for question in user_profile_data["questions"]:
        pass