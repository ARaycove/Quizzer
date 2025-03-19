# All Tests will be contained from running this modules test_client:
from quizzer_database.quizzer_db import QuizzerDB, load_quizzer_db, UserProfilesDB, QuestionObjectDB, UserProfile, QuestionObject
from datetime import datetime, date, timedelta
import threading
import logging
import asyncio

# So upon loading the module, the QuizzerDB will also be loaded
QUIZZER_DB: QuizzerDB = load_quizzer_db()
QUIZZER_DB.QuestionObjectDB._construct_sub_indices()
# Additional references, for great granularity -> each references get's it's own lock
Q_LOCK  = asyncio.Lock()
QUESTION_OBJECT_DB: QuestionObjectDB = QUIZZER_DB.QuestionObjectDB

UP_LOCK = asyncio.Lock()
USER_PROFILE_DB: UserProfilesDB = QUIZZER_DB.UserProfilesDB

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
        self.__active_profile:      UserProfile     = None
        # Instance level lock, prevents spam from UI clients causing race conditions:
        self.__PROFILE_LOCK                         = asyncio.Lock()
        self.__current_question:    QuestionObject  = None

    ###############################################################################
    # Private Function Calls
    ###############################################################################  




    ###############################################################################
    # Core Functionality
    ###############################################################################
    async def get_next_question(self):
        '''
        Question Selection Algorithm
        Prompts Quizzer to run the QSA to determine what should be presented to the user next
        '''
        # Future plans involve a more robust relational graph of question objects to determine this rather than (largely random selection)
        raise NotImplementedError("Not Done Yet Hause")
    
    async def attempt_question(self, status):
        '''
        Provides Quizzer with your answer attempt:
        status: "correct", "incorrect", or "repeat"
        '''
        # if no remaining questions -> await place_question_into_circulation()
        raise NotImplementedError("Not Done Yet Hause")

    ###############################################################################
    # Profile Manipulation
    ###############################################################################
    async def add_new_profile(self, username: str, email_address: str, full_name:str):
        async with Q_LOCK:
            tutorial_questions = QUESTION_OBJECT_DB.get_questions_by_module_name('quizzer tutorial')
        async with UP_LOCK: # Allow instance to add new profiles to Central DB
            USER_PROFILE_DB.add_UserProfile(
            username            =   username,
            email_address       =   email_address,
            full_name           =   full_name,
            tutorial_questions  =   tutorial_questions
            )

    async def load_in_UserProfile(self, email_address):
        async with UP_LOCK: # Request profile information from Central DB
            self.__active_profile: UserProfile = USER_PROFILE_DB.load_UserProfile(email_address=email_address)

    async def add_module_to_user_profile(self, module_name:str):
        # Get list of module questions
        async with Q_LOCK: # Operation should finish in a fraction of a second, but as it scaled this will prevent race conditions
            module_questions = QUESTION_OBJECT_DB.get_questions_by_module_name(module_name)
        # Loop over list
        async with self.__PROFILE_LOCK:
            for question_id in module_questions:
                # Add each id into user profile using the add_question
                self.__active_profile.add_question_to_UserProfile(question_id)
    
    async def remove_module_from_user_profile(self, module_name: str):
        # Get list of module questions
        async with Q_LOCK: # Operation should finish in a fraction of a second, but as it scaled this will prevent race conditions
            module_questions = QUESTION_OBJECT_DB.get_questions_by_module_name(module_name)
        # Loop over list'
        async with self.__PROFILE_LOCK:
            for question_id in module_questions:
                # Deactivate each id in the UserProfile
                self.__active_profile.user_questions.deactive_question(question_id)

    async def deactive_specific_question(self, question_id: str) -> None:
        async with self.__PROFILE_LOCK:
            self.__active_profile.user_questions.deactive_question(question_id)
    ###############################################################################
    # Add, Edit, and Remove Questions
    ###############################################################################
    # This is where we can implement some user permissions. If we want to restrict some users from manipulating the QuestionObjectDB of the QuizzerDB
    
    async def add_new_question_to_QuestionObjectDB(self):
        raise NotImplementedError("Almost There")
    
    async def edit_question_in_QuestionObjectDB(self):
        raise NotImplementedError("Almost There")
    
    async def delete_question_from_QuestionObjectDB(self):
        raise NotImplementedError("Almost There")

    ###############################################################################
    # DB Queries, for UI interface
    ###############################################################################


    ###############################################################################
    # Debug Printouts
    ###############################################################################
    async def print_user_review_schedule():
        raise NotImplementedError("Almost There")

if __name__ == "__main__":
    console = logging.getLogger(__name__)
    logging.basicConfig(filename="Quizzer.log", level=logging.INFO)
    async def DB_test_loop():
        global QUIZZER_DB
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
    async def test_event_loop():
        global QUIZZER_DB
        console.info('Started')
        # First round of tests is to ensure we can effectively access various parts of our QuizzerDB object
        quizzer = Quizzer()
        await DB_test_loop()
        console.info(f"    Adding test profile")
        await quizzer.add_new_profile("test_man", "test@test.com", "Test McTester")
        user_profiles_dict = QUIZZER_DB.UserProfilesDB.__dict__
        console.info(f"    {user_profiles_dict}")

    start = datetime.now()
    asyncio.run(test_event_loop())
    end = datetime.now()
    print(f"Full Test of Quizzer took {end-start}")

    