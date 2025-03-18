# All Tests will be contained from running this modules test_client:
from quizzer_database import QuizzerDB
class Quizzer:
    '''
    Primary Quizzer Instance, this encapsulates the entirety of the Quizzer program
    '''
    def __init__(self):
        Quizzer_DB = QuizzerDB.load_quizzer_db()



if __name__ == "__main__":
    # First round of tests is to ensure we can effectively access various parts of our QuizzerDB object
    quizzer = Quizzer()