from lib import helper
from module_functions import modules
from question_functions import questions
def generate_quizzer_tutorial_question_objects()-> list:
    '''
    returns a Hardcoded list of question objects associated with the Quizzer Tutorial
    designed to be used with the helper.get_question_object_data() function
    is called in case question_object_data.json doesn't exist
    '''
    questions_data = {}
    questions_list = []
    question_one = (questions.add_new_question(
        id = "tutorial_question_one",
        question_text = "Welcome to Quizzer: Click the question to flip over to the answer",
        answer_text = "Now press the checkmark if you get a question correct, or press the cancel circle if you got it wrong. Quizzer is self-scored, and relies on you being honest with yourself!",
        module_name = "Quizzer Tutorial"
    ))

    questions_list.extend([question_one])

    return questions_list

def generate_quizzer_tutorial_module(user_profile_data: dict = None) -> dict:
    pass
    # Initialize the quizzer_tutorial module, as an empty module:
    # quizzer_tutorial_module = modules.verify_and_initialize_module("Quizzer Tutorial")
    # quizzer_tutorial_module["description"] = "This Module is the official tutorial for new users entering Quizzer for the first time.\n" + (
    #     "It is a series of questions, that guide the user through the program, using the main question answer interface"
    # )

    # quizzer_tutorial_module["questions"] = quizzer_tutorial_questions_defines(user_profile_data)


    # # helper.update_module_data(quizzer_tutorial_module)
    # return quizzer_tutorial_module