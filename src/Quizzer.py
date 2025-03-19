# All Tests will be contained from running this modules test_client:
from quizzer_database.quizzer_db import (
    QuizzerDB,          load_quizzer_db,    UserProfilesDB, 
    QuestionObjectDB,   UserProfile,        QuestionObject, 
    QuestionModuleDB,   QuestionModule)
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

    #______________________________________________________________________________
    async def load_in_UserProfile(self, email_address):
        async with UP_LOCK: # Request profile information from Central DB
            self.__active_profile: UserProfile = USER_PROFILE_DB.load_UserProfile(email_address=email_address)

    #______________________________________________________________________________
    async def commit_UserProfile(self):
        '''
        Commits the current state of the user's UserProfile to LTS
        '''
        async with UP_LOCK:
            USER_PROFILE_DB.commit_UserProfile(self.__active_profile)

    #______________________________________________________________________________
    async def add_module_to_user_profile(self, module_name:str):
        # Get list of module questions
        async with Q_LOCK: # Operation should finish in a fraction of a second, but as it scaled this will prevent race conditions
            module_questions = QUESTION_OBJECT_DB.get_questions_by_module_name(module_name)
        # Loop over list
        async with self.__PROFILE_LOCK:
            for question_id in module_questions:
                # Add each id into user profile using the add_question
                self.__active_profile.add_question_to_UserProfile(question_id)

    #______________________________________________________________________________
    async def remove_module_from_user_profile(self, module_name: str):
        # Get list of module questions
        async with Q_LOCK: # Operation should finish in a fraction of a second, but as it scaled this will prevent race conditions
            module_questions = QUESTION_OBJECT_DB.get_questions_by_module_name(module_name)
        # Loop over list'
        async with self.__PROFILE_LOCK:
            for question_id in module_questions:
                # Deactivate each id in the UserProfile
                self.__active_profile.user_questions.deactive_question(question_id)

    #______________________________________________________________________________
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
    def reset_log_file(log_file="Quizzer.log"):
        """Clear the log file or create a new empty one"""
        with open(log_file, 'w') as f:
            f.write(f"--- New Test Run Started: {datetime.now()} ---\n")
        
        # Configure the logger
        logging.basicConfig(
            filename=log_file,
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            filemode='a'  # We've already created/cleared the file, now we can append
        )
        
        # Get the logger
        return logging.getLogger(__name__)
    console = reset_log_file()
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
        console.info("Writing DB to json for further analysis")
        QUIZZER_DB.debug_write_db_to_json()

        console.info("    Questions by Concept")
        concept_list = QUIZZER_DB.QuestionObjectDB.get_list_of_concepts()
        console.info(f"        {concept_list}")

        console.info("    Questions by Subject")
        subject_list = QUIZZER_DB.QuestionObjectDB.get_list_of_subjects()
        console.info(f"        {subject_list}")

        console.info("    Questions by Module")
        module_list  = QUIZZER_DB.QuestionObjectDB.get_list_of_module_names()
        console.info(f"        {module_list}")

        # console.info("Testing get by module, tutorial questions only:")
        # tutorial_questions = QUIZZER_DB.QuestionObjectDB.get_questions_by_module_name('quizzer tutorial')
        # console.info(f"    {tutorial_questions}")

        # console.info("Testing Printout of current profiles")
        # user_profiles_dict = QUIZZER_DB.UserProfilesDB.__dict__
        # console.info(f"    {user_profiles_dict}")

    async def test_user_profile_functionality():
        """
        Comprehensive test of UserProfile functionality that properly commits changes 
        at appropriate points before writing to JSON.
        """
        import random
        
        console.info("==== BEGINNING USER PROFILE FUNCTIONALITY TESTS ====")
        
        # Generate unique test email
        test_email = f"test_user_{datetime.now().strftime('%Y%m%d%H%M%S')}@quizzer.test"
        
        #################################################
        # TEST 1: Create new user profile
        #################################################
        console.info("\n[TEST 1] Creating new user profile")
        quizzer = Quizzer()
        
        try:
            await quizzer.add_new_profile(
                username="TestUser",
                email_address=test_email,
                full_name="Test User Profile"
            )
            console.info(f"✓ Successfully created profile: {test_email}")
            # Note: Profile is already committed in add_UserProfile method
        except Exception as e:
            console.error(f"✗ Failed to create profile: {e}")
            return
        
        #################################################
        # TEST 2: Load user profile
        #################################################
        console.info("\n[TEST 2] Loading user profile")
        
        try:
            await quizzer.load_in_UserProfile(test_email)
            console.info(f"✓ Successfully loaded profile: {test_email}")
            
            profile = quizzer._Quizzer__active_profile
            console.info(f"→ Initial question count: {profile.num_questions}")
        except Exception as e:
            console.error(f"✗ Failed to load profile: {e}")
            return
        
        #################################################
        # TEST 3: Add modules to profile (RANDOMIZED)
        #################################################
        console.info("\n[TEST 3] Adding modules to profile (random selection)")
        
        # Get available modules
        all_modules = list(QUIZZER_DB.QuestionObjectDB.get_list_of_module_names())
        
        # Filter out tutorial module
        available_modules = [m for m in all_modules if m != "quizzer tutorial"]
        
        # Randomly select between 2 and min(10, available) modules
        num_modules = random.randint(2, min(10, len(available_modules)))
        
        # Randomly select modules without replacement
        test_modules = random.sample(available_modules, num_modules)
        
        console.info(f"Randomly selected {num_modules} modules: {test_modules}")
        
        # Add each module
        for module_name in test_modules:
            try:
                profile_before = quizzer._Quizzer__active_profile.num_questions
                console.info(f"→ Adding module: {module_name}")
                await quizzer.add_module_to_user_profile(module_name)
                
                profile_after = quizzer._Quizzer__active_profile.num_questions
                questions_added = profile_after - profile_before
                
                console.info(f"✓ Added module '{module_name}' - {questions_added} questions added")
                
                # Commit after each module addition
                await quizzer.commit_UserProfile()
                console.info(f"  ✓ Profile changes committed after adding module")
            except Exception as e:
                console.error(f"✗ Failed to add module '{module_name}': {e}")
        
        # Log total questions after adding all modules
        total_questions = quizzer._Quizzer__active_profile.num_questions
        console.info(f"→ Total questions after adding all modules: {total_questions}")
        
        # Commit all module additions
        await quizzer.commit_UserProfile()
        console.info(f"  ✓ Profile changes committed after adding all modules")
        
        #################################################
        # TEST 4: Deactivate specific questions
        #################################################
        console.info("\n[TEST 4] Deactivating specific questions")
        
        # Get sample questions to deactivate
        try:
            active_questions = []
            modules_to_sample = random.sample(test_modules, min(3, len(test_modules)))
            
            for module_name in modules_to_sample:
                module_questions = QUESTION_OBJECT_DB.get_questions_by_module_name(module_name)
                if module_questions and len(module_questions) > 0:
                    num_to_sample = random.randint(1, min(3, len(module_questions)))
                    sample_indices = random.sample(range(len(module_questions)), num_to_sample)
                    for idx in sample_indices:
                        active_questions.append(module_questions[idx])
            
            console.info(f"Selected {len(active_questions)} questions for deactivation")
            
            for i, question_id in enumerate(active_questions):
                console.info(f"→ Deactivating question {i+1}: {question_id[:30]}...")
                await quizzer.deactive_specific_question(question_id)
                console.info(f"✓ Question deactivated")
            
            # Commit after deactivating questions
            await quizzer.commit_UserProfile()
            console.info(f"  ✓ Profile changes committed after deactivating questions")
        except Exception as e:
            console.error(f"✗ Error in question deactivation: {e}")
        
        #################################################
        # TEST 5: Remove modules from profile
        #################################################
        console.info("\n[TEST 5] Removing modules from profile")
        
        # Randomly select a subset of modules to remove
        if test_modules:
            modules_to_remove = random.sample(test_modules, random.randint(1, min(3, len(test_modules))))
            console.info(f"Selected {len(modules_to_remove)} modules for removal: {modules_to_remove}")
            
            for module_to_remove in modules_to_remove:
                try:
                    console.info(f"→ Removing module: {module_to_remove}")
                    await quizzer.remove_module_from_user_profile(module_to_remove)
                    console.info(f"✓ Module '{module_to_remove}' removed (questions deactivated)")
                    
                    # Commit after each module removal
                    await quizzer.commit_UserProfile()
                    console.info(f"  ✓ Profile changes committed after removing module")
                except Exception as e:
                    console.error(f"✗ Failed to remove module '{module_to_remove}': {e}")
        
        # Final commit to ensure all changes are saved
        console.info("\n[COMMIT] Final commit of all profile changes")
        await quizzer.commit_UserProfile()
        console.info("✓ All profile changes committed successfully")
        
        #################################################
        # DEBUG JSON OUTPUT
        #################################################
        console.info("\n[DEBUG] Writing current DB state to JSON for inspection")
        try:
            # First ensure the changes are reflected in the DB
            debug_file = QUIZZER_DB.debug_write_db_to_json()
            console.info(f"✓ DB state written to: {debug_file}")
            
            # Now write detailed profile information
            debug_files = QUIZZER_DB.debug_write_UserProfiles_to_json()
            console.info(f"✓ User profiles written to JSON files: {len(debug_files)} files")
        except Exception as e:
            console.error(f"✗ Failed to write debug JSON: {e}")
        
        #################################################
        # TEST SUMMARY
        #################################################
        console.info("\n==== USER PROFILE TESTS COMPLETED ====")
        console.info(f"Profile tested: {test_email}")
        console.info(f"Modules added: {len(test_modules)} ({', '.join(test_modules)})")
        console.info(f"Questions deactivated: {len(active_questions)}")
        console.info(f"Modules removed: {len(modules_to_remove)} ({', '.join(modules_to_remove)})")
        console.info("All test operations completed and committed properly")
    
        return {
            "test_email": test_email,
            "modules_added": test_modules,
            "questions_deactivated": len(active_questions),
            "modules_removed": modules_to_remove
        }


    async def test_event_loop():
        global QUIZZER_DB
        console.info('Started')
        # First round of tests is to ensure we can effectively access various parts of our QuizzerDB object
        quizzer = Quizzer()
        # await DB_test_loop()
        console.info("Starting User Profile functionality tests")
        await test_user_profile_functionality()
        console.info("User Profile tests complete - NO CHANGES COMMITTED")




    start = datetime.now()
    asyncio.run(test_event_loop())
    end = datetime.now()
    print(f"Full Test of Quizzer took {end-start}")

    