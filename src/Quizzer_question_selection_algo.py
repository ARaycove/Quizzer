from lib import quizzer_logger as ql
from quizzer_database.quizzer_db import (
    QuizzerDB,          load_quizzer_db,    UserProfilesDB, 
    QuestionObjectDB,   UserProfile,        QuestionObject, 
    QuestionModuleDB,   QuestionModule)
#______________________________________________________________________________
@ql.log_function()
def select_next_question_for_review(self, question_buffer, question_object_index_ref: dict[QuestionObject]):
    eligible_questions = self.get_eligible_questions(question_buffer)
    minimum_eligible_questions = 100
    ql.log_value("question_object_length", question_object_index_ref)
    while minimum_eligible_questions <= 100:
        self.add_questions_into_circulation(question_object_index_ref=question_object_index_ref)
        break