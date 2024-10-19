from lib import helper
from module_functions import modules
from question_functions import questions

def quizzer_tutorial_questions_defines(user_profile_data: dict = None) -> dict:
    questions_data = {}
    questions_list = []
    question_one = (questions.add_new_question(
        user_profile_data,
        id = "tutorial_question_one",
        question_text = "Welcome to Quizzer: Click the question to flip over to the answer",
        answer_text = "Now press the checkmark if you get a question correct, or press the cancel circle if you got it wrong. Quizzer is self-scored, and relies on you being honest with yourself!",
        module_name = "Quizzer Tutorial"
    ))

    questions_list.extend([question_one])
    for qo in questions_list:
        unique_id = qo["id"]
        write_data = {unique_id: qo}
        questions_data.update(write_data)

    return questions_data
def generate_quizzer_tutorial(user_profile_data: dict = None) -> dict:
    # Initialize the quizzer_tutorial module, as an empty module:
    quizzer_tutorial_module = modules.verify_and_initialize_module("Quizzer Tutorial")
    quizzer_tutorial_module["description"] = "This Module is the official tutorial for new users entering Quizzer for the first time.\n" + (
        "It is a series of questions, that guide the user through the program, using the main question answer interface"
    )
    quizzer_tutorial_module["questions"] = quizzer_tutorial_questions_defines(user_profile_data)


    # helper.update_module_data(quizzer_tutorial_module)
    return quizzer_tutorial_module