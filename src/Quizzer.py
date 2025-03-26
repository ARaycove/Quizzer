# All Tests will be contained from running this modules test_client:
from quizzer_database.quizzer_db import (
    QuizzerDB,          load_quizzer_db,    UserProfilesDB, 
    QuestionObjectDB,   UserProfile,        QuestionObject, 
    QuestionModuleDB,   QuestionModule)
from Quizzer_question_selection_algo import select_next_question_for_review
from lib        import quizzer_logger as ql
from datetime   import datetime, date, timedelta
import random
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
    async def get_next_question(self) -> QuestionObject:
        '''
        Question Selection Algorithm
        Prompts Quizzer to run the QSA to determine what should be presented to the user next
        '''
        async with self.global_Q_LOCK:
            question_object_index_ref = self.QuestionObject_DB.get_reference_to_all_objects
        # Future plans involve a more robust relational graph of question objects to determine this rather than (largely random selection)
        ql.log_value("question_buffer", self.__question_buffer)
        # Pull up revision schedule

        # Get eligible questions from revision schedule
        self.__active_profile.get_next_question_for_review(self.__question_buffer, question_object_index_ref) # Function contains logic to enter new questions into circulation


        # Replace self.__current_question with new QuestionObject selected

        # Add the new question.id to the buffer at index 0

        # If length of buffer is greater than 5 remove the last index with .pop() method
        raise NotImplementedError("Not Done Yet Hause")
    
    @ql.log_function()
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
        async with self.global_UP_LOCK:
            all_accounts = self.UserProfiles_DB.get_all_profile_emails()
            if email_address in all_accounts:
                return ql.log_warning(f"Account with email: {email_address} already exists")
        #---------------
        async with self.global_Q_LOCK:
            ql.log_general_message("Fetching tutorial question list from QuestionObjectDB -> QuestionModuleDB")
            tutorial_questions = self.QuestionObject_DB.get_questions_by_module_name('quizzer tutorial')
            ql.log_success_message(f"No Errors: {tutorial_questions}")
            list_all_modules = self.QuestionObject_DB.get_list_of_module_names()
            list_all_subjects= self.QuestionObject_DB.get_list_of_subjects()

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
            tutorial_questions  =   tutorial_questions,
            list_of_all_modules =   list_all_modules,
            list_of_all_subjects=   list_all_subjects
            )

    #______________________________________________________________________________
    @ql.log_function()
    async def load_in_UserProfile(self, email_address):
        # FIXME Authentication functionality for server deployment

        async with self.global_UP_LOCK: # Request profile information from Central DB
            self.__active_profile: UserProfile = self.UserProfiles_DB.load_UserProfile(email_address=email_address)
            if self.__active_profile:
                ql.log_success_message(f"UserProfile successfully loaded and set\n Value: {self.__active_profile}")
            else:
                return None
            # validation required
        async with self.global_Q_LOCK:
            all_modules = self.QuestionObject_DB.get_list_of_module_names()
        
        async with self.__PROFILE_LOCK:
            # Iterate over all module names and verify all questions that exist in that module have been activated
            for module_name in all_modules:
                ql.log_general_message(f"Validating module: {module_name} in user profile")
                if self.__active_profile.user_settings.get_module_activation_status(module_name):
                    self.add_module_to_user_profile(module_name)
            # ql.log_value("self.__active_profile", self.__active_profile)

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
    async def add_new_question_to_QuestionObjectDB(self,
                 module_name:       str     = None,
                 primary_subject:   str     = None,
                 subjects:          list    = None,
                 related_concepts:  list    = None,
                 question_text:     str     = None,
                 question_audio:    str     = None,
                 question_image:    str     = None,
                 question_video:    str     = None,
                 answer_text:       str     = None,
                 answer_audio:      str     = None,
                 answer_image:      str     = None,   
                 answer_video:      str     = None,
                 ) -> str:
        '''Returns the question_id that was generated'''
        async with self.global_Q_LOCK: #Since we are adding something to the global DB
            try:
                generated_object =      QuestionObject(
                        author          =   self.__active_profile.user_uuid,
                        module_name     =   module_name,
                        primary_subject =   primary_subject,
                        subjects        =   subjects,
                        related_concepts=   related_concepts,
                        question_text   =   question_text,
                        question_audio  =   question_audio,
                        question_image  =   question_image,
                        question_video  =   question_video,
                        answer_text     =   answer_text,
                        answer_audio    =   answer_audio,
                        answer_image    =   answer_image,
                        answer_video    =   answer_video
                    )
                self.QuestionObject_DB.add_new_QuestionObject(
                    generated_object
                )
                # Ensure that we validate the module just created
                # When a user contributes to an existing module, that module should be activated in their profile, validating that all questions are added that belong to that module
            except Exception as e:
                ql.log_error("Question Object was not generated", exception=e)
                return None
        # We need to release the lock in order to add_module validation
        ql.log_general_message("Validating all questions in provided module are added, including the one just added")
        await self.add_module_to_user_profile(module_name) 
        ql.log_success_message(f"Question generated with id: {generated_object.id}")
        return generated_object.id
    
    @ql.log_function()
    async def edit_question_in_QuestionObjectDB(self, 
                                           question_id:        str,
                                           primary_subject:    str = None,
                                           subjects:           list = None,
                                           related_concepts:   list = None,
                                           question_text:      str = None,
                                           question_audio:     str = None,
                                           question_image:     str = None,
                                           question_video:     str = None,
                                           answer_text:        str = None,
                                           answer_audio:       str = None,
                                           answer_image:       str = None,
                                           answer_video:       str = None,
                                           module_name:        str = None):
        """
        Edit a question in the QuestionObjectDB.
        Only provided parameters (non-None) will be updated.
        """
        update_made = False
        async with self.global_Q_LOCK:
            question_object = self.QuestionObject_DB.get_QuestionObject(question_id)
            ql.log_value(f"Referred to Object with {question_id}", question_object)
            if primary_subject is not None:
                ql.log_value("Provided  - primary_subject", primary_subject)
                ql.log_value("Before    - primary_subject", question_object.primary_subject)
                question_object.set_primary_subject_value(primary_subject)
                ql.log_value("After     - primary_subject", question_object.primary_subject)
                update_made = True
            if subjects is not None:
                ql.log_value("Provided  - subjects", subjects)
                ql.log_value("Before    - subjects", question_object.subjects)
                question_object.set_subjects_value(subjects)
                ql.log_value("After     - subjects", question_object.subjects)
                update_made = True
            if related_concepts is not None:
                ql.log_value("Provided  - related_concepts", related_concepts)
                ql.log_value("Before    - related_concepts", question_object.related_concepts)
                question_object.set_related_concepts_value(related_concepts)
                ql.log_value("After     - related_concepts", question_object.related_concepts)
                update_made = True
            if question_text is not None:
                ql.log_value("Provided  - question_text", question_text)
                ql.log_value("Before    - question_text", question_object.question_text)
                question_object.set_question_text_value(question_text)
                ql.log_value("After     - question_text", question_object.question_text)
                update_made = True
            if question_audio is not None:
                ql.log_value("Provided  - question_audio", question_audio)
                ql.log_value("Before    - question_audio", question_object.question_audio)
                question_object.set_question_audio_value(question_audio)
                ql.log_value("After     - question_audio", question_object.question_audio)
                update_made = True
            if question_image is not None:
                ql.log_value("Provided  - question_image", question_image)
                ql.log_value("Before    - question_image", question_object.question_image)
                question_object.set_question_image_value(question_image)
                ql.log_value("After     - question_image", question_object.question_image)
                update_made = True
            if question_video is not None:
                ql.log_value("Provided  - question_video", question_video)
                ql.log_value("Before    - question_video", question_object.question_video)
                question_object.set_question_video_value(question_video)
                ql.log_value("After     - question_video", question_object.question_video)
                update_made = True
            if answer_text is not None:
                ql.log_value("Provided  - answer_text", answer_text)
                ql.log_value("Before    - answer_text", question_object.answer_text)
                question_object.set_answer_text_value(answer_text)
                ql.log_value("After     - answer_text", question_object.answer_text)
                update_made = True
            if answer_audio is not None:
                ql.log_value("Provided  - answer_audio", answer_audio)
                ql.log_value("Before    - answer_audio", question_object.answer_audio)
                question_object.set_answer_audio_value(answer_audio)
                ql.log_value("After     - answer_audio", question_object.answer_audio)
                update_made = True
            if answer_image is not None:
                ql.log_value("Provided  - answer_image", answer_image)
                ql.log_value("Before    - answer_image", question_object.answer_image)
                question_object.set_answer_image_value(answer_image)
                ql.log_value("After     - answer_image", question_object.answer_image)
                update_made = True
            if answer_video is not None:
                ql.log_value("Provided  - answer_video", answer_video)
                ql.log_value("Before    - answer_video", question_object.answer_video)
                question_object.set_answer_video_value(answer_video)
                ql.log_value("After     - answer_video", question_object.answer_video)
                update_made = True
            if module_name is not None:
                ql.log_value("Provided  - module_name", module_name)
                ql.log_value("Before    - module_name", question_object.module_name)
                question_object.set_module_name_value(module_name)
                ql.log_value("After     - module_name", question_object.module_name)
                update_made = True

        if update_made == True:
            ql.log_success_message("Update Arguments were provided, rebuilding sub_indices in QuestionObjectDB")
            async with self.global_Q_LOCK:
                self.QuestionObject_DB._construct_sub_indices()
        else:
            ql.log_warning("No update arguments were provided")

    @ql.log_function()
    async def delete_question_from_QuestionObjectDB(self, question_id):
        self.QuestionObject_DB.delete_QuestionObject(question_id)

    ###############################################################################
    # DB Queries, for UI interface
    ###############################################################################
    @ql.log_function()
    async def get_list_of_user_accounts(self):
        async with self.global_UP_LOCK:
            return self.UserProfiles_DB.get_all_profile_emails()
        
    @ql.log_function()
    async def get_all_module_names(self):
        async with self.global_Q_LOCK:
            return self.QuestionObject_DB.get_list_of_module_names()
        
    @ql.log_function()
    async def get_specific_question(self, question_id):
        async with self.global_Q_LOCK:
            return self.QuestionObject_DB.get_QuestionObject(question_id)

    @ql.log_function()
    async def get_question_selection_buffer(self):
        return_value = self.__question_buffer.copy()
        ql.log_value("Question Buffer", return_value)
        return return_value
    ###############################################################################
    # Debug Printouts
    ###############################################################################
    @ql.log_function()
    async def print_user_review_schedule():
        raise NotImplementedError("Almost There")

if __name__ == "__main__":
    # UserProfile Testing
    async def test_QuizzerDB_initialization():
        ql.log_main_header("Load and Test manipulation of QuizzerDB")
        global QUIZZERDB
        global Q_LOCK
        global UP_LOCK
        # So upon loading the module, the QuizzerDB will also be loaded
        QUIZZERDB = load_quizzer_db() # Construct sub_indices upon load, embedded in load function now
        # Additional references, for great granularity -> each references get's it's own lock
        Q_LOCK  = asyncio.Lock()
        UP_LOCK = asyncio.Lock()
    
    def log_user_profile_UserQuestionDB_values(quizzer):
        ql.log_section_header("UserProfileQuestionsDB values")
        ql.log_value("UserQuestions", quizzer._Quizzer__active_profile.user_questions.__dict__)
    
    def log_user_profile_UserProfileSettingsDB_values(quizzer):
        ql.log_section_header("UserProfileSettingsDB values")
        for setting_name, setting_value in quizzer._Quizzer__active_profile.user_settings.__dict__.items():
            # Skip private attributes
            if setting_name.startswith('__'):
                continue
            
            ql.log_general_message(f"▶ {setting_name}")
            
            # Handle ComplexUserSetting objects
            if hasattr(setting_value, 'name') and hasattr(setting_value, 'description'):
                ql.log_general_message(f"  Name: {setting_value.name}")
                ql.log_general_message(f"  Description: {setting_value.description}")
                
                # Log nested settings if they exist
                if hasattr(setting_value, 'nested_settings') and setting_value.nested_settings:
                    ql.log_general_message("  Settings:")
                    for nested_name, nested_setting in setting_value.nested_settings.items():
                        value = nested_setting.value if hasattr(nested_setting, 'value') else "[No value]"
                        ql.log_general_message(f"    • {nested_name}: {value}")
            
            # Handle simple attributes
            elif not hasattr(setting_value, '__dict__'):
                ql.log_general_message(f"  Value: {setting_value}")
            
            # For other objects, show a summary
            else:
                attrs = [f"{k}: {v}" for k, v in setting_value.__dict__.items() 
                        if not k.startswith('__') and not isinstance(v, dict) and not hasattr(v, '__dict__')]
                ql.log_general_message(f"  Attributes: {', '.join(attrs[:3])}{'...' if len(attrs) > 3 else ''}")

    def log_user_profile_UserProfileStatsDB_values(quizzer):
        ql.log_section_header("UserProfileStatsDB values")
        user_stats = quizzer._Quizzer__active_profile.user_stats

        # Handle Historical Stats
        ql.log_general_message("▶ Historical Statistics:")
        for attr_name, attr_value in user_stats.__dict__.items():
            # Skip private attributes, UserQuestionDB reference, and UserSettingsDB reference
            if attr_name.startswith('_') or attr_name in ['__UserQuestionsDB_REF', '__UserSettingsDB_REF']:
                continue
            
            # If this is a HistoricalUserStat object
            if hasattr(attr_value, 'name') and hasattr(attr_value, 'value_most_recent'):
                ql.log_general_message(f"  • {attr_value.name}:")
                ql.log_general_message(f"    Description: {attr_value.description}")
                
                # Log the most recent value
                recent_value = attr_value.value_most_recent
                ql.log_general_message(f"    Current value: {recent_value}")
                
                # Add trend information if available
                if hasattr(attr_value, 'trend') and attr_value.trend is not None:
                    trend_direction = "↑" if attr_value.trend > 0 else "↓" if attr_value.trend < 0 else "→"
                    ql.log_general_message(f"    Trend: {trend_direction} {abs(attr_value.trend):.2f}")
                    
                # Log min/max if available
                if hasattr(attr_value, 'max_value') and attr_value.max_value is not None:
                    ql.log_general_message(f"    Maximum: {attr_value.max_value}")
                
                # Log data points count if available
                if hasattr(attr_value, 'nested_stats'):
                    ql.log_general_message(f"    Data points: {len(attr_value.nested_stats)}")
            
            # If this is a UserStat object (non-historical)
            elif hasattr(attr_value, 'name') and hasattr(attr_value, 'value'):
                ql.log_general_message(f"  • {attr_value.name}: {attr_value.value}")
                if hasattr(attr_value, 'description') and attr_value.description:
                    ql.log_general_message(f"    Description: {attr_value.description}")
            
            # For other types of values
            else:
                ql.log_general_message(f"  • {attr_name}: {attr_value}")

        # Log derived properties
        ql.log_general_message("\n▶ Current Stats:")
        if hasattr(user_stats, 'current_eligible_questions'):
            ql.log_general_message(f"  • Eligible Questions: {user_stats.current_eligible_questions}")
        if hasattr(user_stats, 'average_daily_increase_in_total_circulating_questions'):
            ql.log_general_message(f"  • Daily Increase Rate: {user_stats.average_daily_increase_in_total_circulating_questions:.2f} questions/day")
        if hasattr(user_stats, 'number_of_days_until_reserve_questions_are_exhausted'):
            days = user_stats.number_of_days_until_reserve_questions_are_exhausted
            if days > 9999:
                ql.log_general_message(f"  • Reserve Exhaustion: Never (stable or decreasing)")
            else:
                ql.log_general_message(f"  • Reserve Exhaustion: {days:.1f} days")

    def log_user_profile_values(quizzer):
        log_user_profile_UserQuestionDB_values(quizzer)
        log_user_profile_UserProfileSettingsDB_values(quizzer)
        log_user_profile_UserProfileStatsDB_values(quizzer)

    async def test_user_profile_initialization(quizzer: Quizzer):
        ql.log_main_header("Testing User Profile Creation and Initialization")
        #--------------------------------------------------------
        ql.log_section_header("Test: Add new profile")
        await quizzer.add_new_profile(
            username        = "Test_Profile",
            email_address   = "this@test.com",
            full_name       = "Big Daddy Test"
        )
        #--------------------------------------------------------
        ql.log_section_header("Test: Add profile that already exists")
        ql.log_general_message("Attempting to add a profile that already exists:")
        ql.log_general_message("We should now get a warning stating that the profile already exists")
        await quizzer.add_new_profile(
            username        = "Test_Profile",
            email_address   = "this@test.com",
            full_name       = "Big Daddy Test"
        )

        #--------------------------------------------------------
        ql.log_section_header("Test: Load new profile into __active_profile")
        #--------------------------------------------------------
        ql.log_section_header("Test loading non-existent profile")
        await quizzer.load_in_UserProfile("Hello@non_here.com")
        #--------------------------------------------------------
        ql.log_section_header("Test loading newly created profile")
        await quizzer.load_in_UserProfile("this@test.com")

        #--------------------------------------------------------
        ql.log_section_header("Logging Initial Values of Fresh Profile")
        log_user_profile_values(quizzer)

        #--------------------------------------------------------
        ql.log_section_header("Testing Addition and removal of modules")
        ql.log_general_message("Getting list of modules in Quizzer_DB")
        all_modules = await quizzer.get_all_module_names()

        ql.log_general_message("Selecting random module to add")
        random_index = random.randint(0, len(all_modules)-1)
        random_module = all_modules[random_index]
        ql.log_value(f"random_module", random_module)

        #######################################################################################
        # # These tests have passed, cluttering the log: 
        # #--------------------------------------------------------
        # ql.log_section_header("Adding selected module")
        # await quizzer.add_module_to_user_profile(random_module)
        # ql.log_general_message("Should now see these questions in the review schedule, under reserve_bank")
        # log_user_profile_UserQuestionDB_values(quizzer)

        # ql.log_general_message("Adding module that's already been added -> expected result is to just repeat the same process with no errors. New questions may or may not exist, so it doesn't hurt to just rerun")

        # ql.log_general_message("Logging Values of Profile now that module has been added")
        # #--------------------------------------------------------
        # ql.log_section_header("Deactivating Module")
        # await quizzer.remove_module_from_user_profile(random_module)

        # ql.log_general_message("Logging Values of Profile now that module is deactivated")
        # ql.log_general_message("Should now see the questions moved to the deactivated column of the review schedule")
        # log_user_profile_UserQuestionDB_values(quizzer)
        # #--------------------------------------------------------
        # ql.log_section_header("Adding selected module")
        # await quizzer.add_module_to_user_profile(random_module)
        # ql.log_general_message("Should now see these questions in the review schedule, under reserve_bank")
        # log_user_profile_UserQuestionDB_values(quizzer)

        # ql.log_general_message("Adding module that's already been added -> expected result is to just repeat the same process with no errors. New questions may or may not exist, so it doesn't hurt to just rerun")

        # ql.log_general_message("Logging Values of Profile now that module has been added")
        #######################################################################################

        #--------------------------------------------------------
        ql.log_section_header("Flowing into next test, activating all modules for test_profile")
        for module in all_modules:
            await quizzer.add_module_to_user_profile(module)
        # log_user_profile_UserQuestionDB_values(quizzer)

    async def test_QuizzerDB_add_remove_questions(quizzer: Quizzer):
        ql.log_main_header("Testing the addition of and removal of Questions from Central QuestionObjectDB")
        ql.log_section_header("Test: Adding Questions to QuizzerDB")

        ql.log_section_header("Test: attempt add call with invalid arguments")
        question_ID = await quizzer.add_new_question_to_QuestionObjectDB()
        ql.log_general_message("question_ID assignment should be none with invalid call")
        ql.log_value("question_ID", question_ID)


        ql.log_section_header("Test: Adding question with valid arguments:")
        question_ID = await quizzer.add_new_question_to_QuestionObjectDB(
            module_name     = "some_module",
            primary_subject = "miscellaneous",
            question_text   = "What is this question?",
            answer_text     = "It's a test question"
        )
        ql.log_value("has_id", question_ID)
        if question_ID != None:
            ql.log_success_message("Question ID is not None")
            ql.log_general_message("Now Testing existence of Added Question")
            question_object = await quizzer.get_specific_question(question_ID)
            ql.log_value("Confirming Object. . .", question_object.__dict__)
        
        
        ql.log_section_header("Test: Editing Question")
        ql.log_section_header("Test: Edit question, but provide no arguments")
        await quizzer.edit_question_in_QuestionObjectDB(question_ID)

        # Excessive performance, thus comment out edit test.
        # ql.log_section_header("Test: edit question, for each property")
        # test_primary_subject = "test_subject"
        # test_subjects = ["a", "b", "c"]
        # test_concepts = ["add", "subtract", "nonsense"]
        # test_question_text = "Some question is here. . ."
        # test_question_audio = "audio.wav"
        # test_question_image = "image.png"
        # test_question_video = "video.mp4"
        # test_answer_text    = "Some answer is here . . ."
        # test_answer_audio   = "audio_02.wav"
        # test_answer_image   = "image_02.png"
        # test_answer_video   = "video_02.mp4"
        # test_module_name    = "some_new_module_here"
        # await quizzer.edit_question_in_QuestionObjectDB(question_id=question_ID,
        #     primary_subject     = test_primary_subject,
        #     subjects            = test_subjects,
        #     related_concepts    = test_concepts,
        #     question_text       = test_question_text,
        #     question_audio      = test_question_audio,
        #     question_image      = test_question_image,
        #     question_video      = test_question_video,
        #     answer_text         = test_answer_text,
        #     answer_audio        = test_answer_audio,
        #     answer_image        = test_answer_image,
        #     answer_video        = test_answer_video,
        #     module_name         = test_module_name,
        #     )



        ql.log_general_message("Individual QuestionObjects should keep of record of who edited the object over time")
        #FIXME

        ql.log_section_header("Test: Removing Question from QuizzerDB")
        await quizzer.delete_question_from_QuestionObjectDB(question_ID)


        ql.log_general_message("Testing lack of existence of Removed Question: {question_id}")
        result = await quizzer.get_specific_question(question_ID)
        if result == None:
            ql.log_success_message("Test Question was deleted successfully")

    async def test_question_selection_algorithm(quizzer: Quizzer):
        ql.log_main_header("Testing Question Selection Algorithm")
        ql.log_section_header("Only testing get_next_question and put_into_circulation functions")
        # First Get
        ql.log_general_message("Question Selection Buffer should be empty")
        next_question = await quizzer.get_next_question()
        # In the loop we'll run next_question then call quizzer.attempt_question()

        # First Get
        ql.log_general_message(f"Question Selection Buffer should be empty")
        next_question = await quizzer.get_next_question()


        # Second Get
        ql.log_general_message(f"Question Selection Buffer should now have 1 question_id")
        next_question = await quizzer.get_next_question()

        
        # Third Get
        ql.log_general_message(f"Question Selection Buffer should now have 2 question_id")
        next_question = await quizzer.get_next_question()


        # Fourth Get
        ql.log_general_message(f"Question Selection Buffer should now have 3 question_id")
        next_question = await quizzer.get_next_question()

        # Fifth Get
        ql.log_general_message(f"Question Selection Buffer should now have 4 question_id")
        next_question = await quizzer.get_next_question()

        # Sixth Get
        ql.log_general_message(f"Question Selection Buffer should now have 5 question_id")
        next_question = await quizzer.get_next_question()
        
        # Seventh Get
        ql.log_general_message(f"Question Selection Buffer should now have 6 question_id")
        next_question = await quizzer.get_next_question()

        ql.log_general_message("Test prioritization mechanics based on subject interest")
        ql.log_general_message("Test prioritization mechanics based on priority values")
        ql.log_general_message("Test algorithm handling of empty reserve bank (with or without deactivated questions)")

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

    async def test_deletion_cleanup_functions(quizzer):
        ql.log_section_header("Test: Remove Added Profile")

        ql.log_general_message("Ensuring profile is now missing from UserProfileDB")

    async def test_event_loop():
        global QUIZZERDB
        global Q_LOCK
        global UP_LOCK
        test_1_pass = True
        test_2_pass = False
        test_3_pass = False
        test_4_pass = False
        test_5_pass = False



        
        await test_QuizzerDB_initialization()
        ql.log_main_header("Testing Quizzer Startup Initialization")
        quizzer = Quizzer(UP_LOCK, Q_LOCK, QUIZZERDB)

        await test_user_profile_initialization(quizzer)
        if test_1_pass == False:
            await test_QuizzerDB_add_remove_questions(quizzer)

        if test_2_pass == False:
            await test_question_selection_algorithm(quizzer)


        if test_3_pass == False:
            pass

        if test_4_pass == False:
            pass

        if test_5_pass == False:
            pass




    start = datetime.now()
    asyncio.run(test_event_loop())
    end = datetime.now()
    print(f"Full Test of Quizzer took {end-start}")

    