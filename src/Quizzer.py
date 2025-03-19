# All Tests will be contained from running this modules test_client:
from quizzer_database.quizzer_db import QuizzerDB, load_quizzer_db, UserProfilesDB, QuestionObjectDB, UserProfile
from datetime import datetime, date, timedelta
import threading
import logging
import asyncio

# So upon loading the module, the QuizzerDB will also be loaded
LOCK = asyncio.Lock()
QUIZZER_DB: QuizzerDB = load_quizzer_db()
QUIZZER_DB.QuestionObjectDB._construct_sub_indices()

class Quizzer:
    '''
    Primary Quizzer Instance, this encapsulates the entirety of the Quizzer program
    One instance of Quizzer per user
    The Quizzer_DB is a class variable, so is shared by all instances
    '''
    ###############################################################################
    # Dunder Mefflin's, We all love Pam and Jim
    ###############################################################################
    def __init__(self, Quizzer_DB = None):  
        self.__active_profile:      UserProfile = None

    ###############################################################################
    # Profile Manipulation
    ###############################################################################
    async def add_new_profile(self, username: str, email_address: str, full_name:str):
        async with LOCK:
            tutorial_questions = QUIZZER_DB.QuestionObjectDB.get_questions_by_module_name('quizzer tutorial')
            QUIZZER_DB.UserProfilesDB.add_UserProfile(
            username            =   username,
            email_address       =   email_address,
            full_name           =   full_name,
            tutorial_questions  =   tutorial_questions
            )
            

    async def load_in_UserProfile(self):
        pass

    async def add_module_to_user_profile(self, module_name:str, email_address):
        raise NotImplementedError("Not Done Yet Hause")



if __name__ == "__main__":
    console = logging.getLogger(__name__)
    logging.basicConfig(filename="Quizzer.log", level=logging.INFO)
    async def test_event_loop():
        global QUIZZER_DB
        console.info('Started')
        # First round of tests is to ensure we can effectively access various parts of our QuizzerDB object
        quizzer = Quizzer()

        console.info("Now Testing Get and Fetch from QuestionObjectDB")
        console.info("    Commit DB")
        QUIZZER_DB.commit_QuizzerDB()
        console.info("        No Errors")
        console.info("    Load DB again")
        QUIZZER_DB = load_quizzer_db()
        console.info("        No Errors")

        console.info("    Questions by Concept")
        concept_list = QUIZZER_DB.QuestionObjectDB.get_list_of_concepts()
        console.info(f"        {concept_list}")

        console.info("    Questions by Subject")
        subject_list = QUIZZER_DB.QuestionObjectDB.get_list_of_subjects()
        console.info(f"        {subject_list}")

        console.info("    Questions by Module")
        module_list  = QUIZZER_DB.QuestionObjectDB.get_list_of_module_names()
        console.info(f"        {module_list}")

        console.info("Testing get by module, tutorial questions only:")
        tutorial_questions = QUIZZER_DB.QuestionObjectDB.get_questions_by_module_name('quizzer tutorial')
        console.info(f"    {tutorial_questions}")

        console.info("Testing Printout of current profiles")
        user_profiles_dict = QUIZZER_DB.UserProfilesDB.__dict__
        console.info(f"    {user_profiles_dict}")
        console.info(f"    Adding test profile")
        await quizzer.add_new_profile("test_man", "test@test.com", "Test McTester")
        user_profiles_dict = QUIZZER_DB.UserProfilesDB.__dict__
        console.info(f"    {user_profiles_dict}")

    start = datetime.now()
    asyncio.run(test_event_loop())
    end = datetime.now()
    print(f"Full Test of Quizzer took {end-start}")

    