# All Tests will be contained from running this modules test_client:
from quizzer_database.quizzer_db import (
    QuizzerDB,          load_quizzer_db,    UserProfilesDB, 
    QuestionObjectDB,   UserProfile,        QuestionObject, 
    QuestionModuleDB,   QuestionModule)
from lib        import quizzer_logger as ql
from datetime   import datetime, date, timedelta
import threading
import logging
import asyncio
QUIZZERDB   = None
Q_LOCK      = None
UP_LOCK     = None

class Quizzer:
    '''
    Primary Quizzer Instance, this encapsulates the entirety of the Quizzer program
    One instance of Quizzer per user
    The Quizzer_DB is a class variable, so is shared by all instances
    '''
    ###############################################################################
    # Dunder Mefflin's, We all love Pam and Jim
    ###############################################################################
    @ql.log_function()
    def __init__(self,
                 global_UP_LOCK:    asyncio.Lock,
                 global_Q_LOCK:     asyncio.Lock,
                 Quizzer_DB = None
                 ):  
        #---------------
        # Pass in global reference to QuizzerDB object (all instances of Quizzer will share this variable)
        ql.log_general_message("Initialize Reference to QuizzerDB")
        self.Quizzer_DB = Quizzer_DB
        if isinstance(self.Quizzer_DB, QuizzerDB):
            ql.log_success_message("Passed QuizzerDB Reference is of proper type: QuizzerDB")
        else:
            ql.log_error("Passed Quizzer Database is not of proper type, must be of type(QuizzerDB)")
            raise TypeError("self.Quizzer_DB must be of type QuizzerDB")
        ##### Ensure granular references for individual locks #####
        #---------------
        # QuestionObjectDB global reference
        ql.log_general_message("Initializing reference to Global QuestionObjectDB")
        self.QuestionObject_DB   = self.Quizzer_DB.QuestionObjectDB
        if isinstance(self.QuestionObject_DB, QuestionObjectDB):
            ql.log_success_message("Reference to QuestionObjectDB is of type QuestionObjectDB")
        else:
            ql.log_error("Reference to QuestionObjectDB is not of type QuestionObjectDB")
            raise TypeError("self.QuestionObject_DB is not of type QuestionObjectDB")

        #---------------
        # UserProfileDB global reference
        self.UserProfiles_DB      = self.Quizzer_DB.UserProfilesDB
        if isinstance(self.UserProfiles_DB, UserProfilesDB):
            ql.log_success_message("Reference to UserProfilesDB is of type UserProfileDB")
        else:
            ql.log_error("Reference to UserProfilesDB is not of type UserProfilesDB")
            raise TypeError("self.UserProfiles_DB is not of type UserProfilesDB")
        ##### Initialize Locks #####
        #---------------
        # Global UserProfileDB Lock
        self.global_UP_LOCK = global_UP_LOCK
        if isinstance(self.global_UP_LOCK, asyncio.Lock):
            ql.log_success_message("Reference to global UserProfile lock is of proper type asyncio.Lock")
        else:
            ql.log_error("Reference to global UserProfile lock is not of type asyncio.Lock")
            raise TypeError("self.global_UP_LOCK is not of type asyncio.Lock")
        
        #---------------
        # Global QuestionObjectDB Lock
        self.global_Q_LOCK  = global_Q_LOCK
        if isinstance(self.global_Q_LOCK, asyncio.Lock):
            ql.log_success_message("Reference to global QuestionObjectDB lock is of proper type asyncio.Lock")
        else:
            ql.log_error("Reference to global QuestionObjectDB lock is not of type asyncio.Lock")
            raise TypeError("self.global_Q_LOCK is not of type asyncio.Lock")
        #---------------
        # Instance level lock, prevents spam from UI clients causing race conditions:
        ql.log_general_message("Setting asyncio locks for instance")
        self.__PROFILE_LOCK                         = asyncio.Lock()
        self.__USER_QUESTIONS_LOCK                  = asyncio.Lock()
        self.__USER_STATS_LOCK                      = asyncio.Lock()


        #---------------
        self.__active_profile:      UserProfile     = None
        ql.log_general_message("Upon Initialization current active profile should be empty/null/None")
        if self.__active_profile == None:
            ql.log_success_message("Active Profile has not be set yet")
        else:
            ql.log_error("Active profile has been set for some reason")
            raise Exception("Crashing program, please address issue to continue")
        #---------------
        # Question Buffer to prevent race conditions and question repitition
        self.__question_buffer = [] # list of question_id's to be passed into the question selection algorithm
        ql.log_general_message("Initialized empty question_buffer list as self.__question_buffer")
        ql.log_value("self.__question_buffer", self.__question_buffer)

        #---------------
        # Holds current question in state
        ql.log_general_message("Initializing __current_question instance variable, should be set None as initial state")
        self.__current_question:    QuestionObject  = None
        if self.__current_question == None:
            ql.log_success_message(f"__current_question not set as expected: {self.__current_question}")
        else:
            ql.log_error(f"__current_question is set for some reason: {self.__current_question}")
            raise Exception("Crashing program, please address issue to continue")
    ###############################################################################
    # Private Function Calls
    ###############################################################################  




    ###############################################################################
    # Core Functionality
    ###############################################################################
    @ql.log_function()
    async def get_next_question(self):
        '''
        Question Selection Algorithm
        Prompts Quizzer to run the QSA to determine what should be presented to the user next
        '''
        # Future plans involve a more robust relational graph of question objects to determine this rather than (largely random selection)
        raise NotImplementedError("Not Done Yet Hause")
    
    ql.log_function()
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
    ql.log_function()
    async def add_new_profile(self, username: str, email_address: str, full_name:str):
        #---------------
        async with self.global_Q_LOCK:
            ql.log_general_message("Fetching tutorial question list from QuestionObjectDB -> QuestionModuleDB")
            tutorial_questions = self.QuestionObject_DB.get_questions_by_module_name('quizzer tutorial')
            ql.log_success_message(f"No Errors: {tutorial_questions}")

        #---------------
        async with self.global_UP_LOCK: # Allow instance to add new profiles to Central DB
            ql.log_general_message("Passing Along Values to new profile creation")
            ql.log_value("username", username)
            ql.log_value("email_address", email_address)
            ql.log_value("full_name", full_name)
            self.UserProfiles_DB.add_UserProfile(
            username            =   username,
            email_address       =   email_address,
            full_name           =   full_name,
            tutorial_questions  =   tutorial_questions
            )

    #______________________________________________________________________________
    @ql.log_function()
    async def load_in_UserProfile(self, email_address):
        # FIXME Authentication functionality for server deployment

        async with self.global_UP_LOCK: # Request profile information from Central DB
            self.__active_profile: UserProfile = self.UserProfiles_DB.load_UserProfile(email_address=email_address)
            if self.__active_profile:
                ql.log_success_message(f"UserProfile successfully loaded and set\n Value: {self.__active_profile}")

    #______________________________________________________________________________
    @ql.log_function()
    async def commit_UserProfile(self):
        '''
        Commits the current state of the user's UserProfile to LTS
        '''
        async with self.global_UP_LOCK:
            self.UserProfiles_DB.commit_UserProfile(self.__active_profile)
            ql.log_success_message(f"User Profile Saved to LTS (Long Term Storage)\nProfile Email:{self.__active_profile.email_address}")

    #______________________________________________________________________________
    @ql.log_function()
    async def add_module_to_user_profile(self, module_name:str):
        # Get list of module questions
        async with self.global_Q_LOCK: # Operation should finish in a fraction of a second, but as it scaled this will prevent race conditions
            module_questions = self.QuestionObject_DB.get_questions_by_module_name(module_name)
        # Loop over list
        async with self.__USER_QUESTIONS_LOCK:
            for question_id in module_questions:
                # Add each id into user profile using the add_question
                self.__active_profile.add_question_to_UserProfile(question_id)

    #______________________________________________________________________________
    @ql.log_function()
    async def remove_module_from_user_profile(self, module_name: str):
        # Get list of module questions
        async with self.global_Q_LOCK: # Operation should finish in a fraction of a second, but as it scaled this will prevent race conditions
            module_questions = self.QuestionObject_DB.get_questions_by_module_name(module_name)
        # Loop over list'
        async with self.__PROFILE_LOCK:
            for question_id in module_questions:
                # Deactivate each id in the UserProfile
                self.__active_profile.user_questions.deactive_question(question_id)

    #______________________________________________________________________________
    @ql.log_function()
    async def deactive_specific_question(self, question_id: str) -> None:
        async with self.__USER_QUESTIONS_LOCK:
            self.__active_profile.user_questions.deactive_question(question_id)
    ###############################################################################
    # Add, Edit, and Remove Questions
    ###############################################################################
    # This is where we can implement some user permissions. If we want to restrict some users from manipulating the QuestionObjectDB of the QuizzerDB
    @ql.log_function()
    async def add_new_question_to_QuestionObjectDB(self):
        raise NotImplementedError("Almost There")
    
    @ql.log_function()
    async def edit_question_in_QuestionObjectDB(self):
        raise NotImplementedError("Almost There")
    
    @ql.log_function()
    async def delete_question_from_QuestionObjectDB(self):
        raise NotImplementedError("Almost There")

    ###############################################################################
    # DB Queries, for UI interface
    ###############################################################################


    ###############################################################################
    # Debug Printouts
    ###############################################################################
    @ql.log_function()
    async def print_user_review_schedule():
        raise NotImplementedError("Almost There")

if __name__ == "__main__":
    # UserProfile Testing
    async def test_QuizzerDB():
        ql.log_main_header("Load and Test manipulation of QuizzerDB")
        global QUIZZERDB
        global Q_LOCK
        global UP_LOCK
        # So upon loading the module, the QuizzerDB will also be loaded
        QUIZZERDB = load_quizzer_db() # Construct sub_indices upon load, embedded in load function now
        # Additional references, for great granularity -> each references get's it's own lock
        Q_LOCK  = asyncio.Lock()
        UP_LOCK = asyncio.Lock()

        ql.log_section_header("Test: Adding Question to QuizzerDB")

        ql.log_general_message("Now Testing existence of Added Question")



        ql.log_section_header("Test: Editing Question")
        ql.log_general_message("Before State of Added Question: {question_id}")

        ql.log_general_message("After State of Added Question: {question_id}")


        ql.log_section_header("Test: Removing Question from QuizzerDB")
        ql.log_general_message("Testing lack of existence of Removed Question: {question_id}")



    async def test_user_profile_initialization(quizzer):
        ql.log_main_header("Testing User Profile Creation and Initialization")

        ql.log_section_header("Test: Add new profile")

        ql.log_section_header("Logging Initial Values of Fresh Profile")

        ql.log_section_header("UserProfileQuestionsDB values")

        ql.log_section_header("UserProfileSettingsDB values")

        ql.log_section_header("UserProfileStatsDB values")

        ql.log_general_message("Getting list of modules in Quizzer_DB")

        ql.log_general_message("Selecting random module to add")

        ql.log_general_message("Adding selected module")

        ql.log_general_message("Logging Values of Profile now that module has been added")

        ql.log_general_message("Deactivating Module")

        ql.log_general_message("Logging Values of Profile now that module is deactivated")
        


        ql.log_section_header("Test: Remove Added Profile")

        ql.log_general_message("Ensuring profile is now missing from UserProfileDB")



    async def test_question_selection_algorithm(quizzer):
        ql.log_main_header("Testing Question Selection Algorithm")

        ql.log_general_message(f"Question Selection Buffer should be at most 5 questions long")

        ql.log_general_message("Test prioritization mechanics based on subject interest")

        ql.log_general_message("Test prioritization mechanics based on priority values")

        ql.log_general_message("Test algorithm handling of empty reserve bank (with or without deactivated questions)")

        ql.log_general_message("If bank is empty, selection buffer should be over-ridden")
        # I am considering ensuring that there is always a large amount of questions eligible, this would ensure that questions do extend past there due_date, which would ensure we get more varied data
        ql.log_general_message("Test when no questions are eligible: should add new questions into circulation whenever there are n (50?) or less questions eligible")

    async def test_quizzer_main_loop(quizzer):
        ql.log_main_header("Testing Full system behavior")
        ql.log_general_message("logging StatsDB Values")
        # Test Loop 5 times
        ql.log_general_message("Get First Question to Answer")
        ql.log_general_message("log state of UserQuestionObject")

        ql.log_general_message("Add correct Attempt record")        

        ql.log_general_message("logging StatsDB Values after attempt is made")
        ql.log_general_message("logging after-state of UserQuestionObject")
        ql.log_general_message("logging buffer state")


        ql.log_general_message("Add incorrect Attempt record")        

        ql.log_general_message("logging StatsDB Values after attempt is made")
        ql.log_general_message("logging after-state of UserQuestionObject")
        ql.log_general_message("logging buffer state")
        
        ql.log_general_message("Add repeat Attempt record")        

        ql.log_general_message("logging StatsDB Values after attempt is made")
        ql.log_general_message("logging after-state of UserQuestionObject")
        ql.log_general_message("logging buffer state")

    async def test_event_loop():
        global QUIZZERDB
        global Q_LOCK
        global UP_LOCK
        
        
        await test_QuizzerDB()
        ql.log_main_header("Testing Quizzer Startup Initialization")

        quizzer = Quizzer(UP_LOCK, Q_LOCK, QUIZZERDB)
        await test_user_profile_initialization(quizzer)

        await test_question_selection_algorithm(quizzer)

        await test_quizzer_main_loop(quizzer)




    start = datetime.now()
    asyncio.run(test_event_loop())
    end = datetime.now()
    print(f"Full Test of Quizzer took {end-start}")

    