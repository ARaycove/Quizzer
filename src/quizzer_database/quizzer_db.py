import sys
import os
# Fixes the module import issue
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from quizzer_database.user_profile import UserProfile, QuestionObject
from quizzer_database.DB_utils import util_QuizzerV4ObjDict_to_QuestionObject
from lib import quizzer_logger as ql
import pickle

class QuestionModule:
    @ql.log_function()
    def __init__(self, 
                 module_name:       str, 
                 description:       str,
                 author:            str,
                 subjects_covered:  list    =   [].copy(),
                 concepts_covered:  list    =   [].copy(),
                 questions:         list    =   [].copy()
                 ):
        self.module_name:       str         =   module_name
        self.author:            str         =   author
        self.description:       str         =   description
        self.primary_subject:   str         =   ""
        self.subjects_covered:  list[str]   =   subjects_covered
        self.concepts_covered:  list[str]   =   concepts_covered
        self.questions:         list[str]   =   questions
        self.total_questions:   int         =   len(questions)
        # Good luck reading that
        self.update_module(author,description=description,subjects_covered=subjects_covered,concepts_covered=concepts_covered,questions=questions)
        ql.log_general_message(f"Module: {self.module_name} values are now:")
        ql.log_value("self.author", self.author)
        ql.log_value("self.description", self.description)
        ql.log_value("self.primary_subject", self.primary_subject)
        ql.log_value("self.subjects_covered", self.subjects_covered)
        ql.log_value("self.concepts_covered", self.concepts_covered)
        ql.log_value("self.questions", self.questions)
        ql.log_value("self.total_questions", self.total_questions)

    ql.log_function()
    def __str__(self):
        return str(self.__dict__)
    #______________________________________________________________________________
    ql.log_function()
    def update_module(
            self,
            author:             str         =   None,
            description:        str         =   None,
            subjects_covered:   list[str]   =   None, 
            concepts_covered:   list[str]   =   None, 
            questions:          list[str]   =   None
            ):
        '''
        Takes any combination of arguments, if an argument is provided for a given instance variable it will be updated, if not provided, value defaults to None, and is not updated
        '''
        # Check author, and update if not None
        if author           != None:
            self.author = author
        
        # Check description, and update if not None
        if description      != None:
            self.description = description

        # Check list of provided subjects, and update if not None
        if subjects_covered != None:
            # Assign as a set
            self.subjects_covered = set(subjects_covered)
            big_1 = 0 # max_count tracker
            for subj in self.subjects_covered: # iterate over the set
                count = subjects_covered.count(subj) # Get count of that subject
                if count > big_1: # If it's greater than the current max, assign it as the primary subject
                    big_1 = count
                    self.primary_subject = subj

        # Check list of provided concepts, and update if not None
        if concepts_covered != None:
            # Assign as a set
            self.concepts_covered = set(concepts_covered)  
            # No primary concept logic needed
        
        # Check list of provided question_ids, and update if not None
        if questions        != None:
            self.questions = questions
            # Since the question list has been updated we should also update the total number instance var
            self.total_questions = len(questions)

class QuestionModuleDB():
    '''
    Stores QuestionModule Objects
    contains one instance variable
    self.index = {} in the form {module_name: QuestionModule}
    '''
    ###############################################################################
    # Cool Dunder Methods
    ###############################################################################
    ql.log_function()
    def __init__(self):
        self.index = {}
        ql.log_general_message(f"Should be an empty dictionary")
        ql.log_value(f"self.index", self.index)
        if not self.index:
            ql.log_error(f"self.index initialized to a non_empty dictionary")
            raise TypeError("Something is causing init to fail")

    ###############################################################################
    # Abstract complicated dictionary operations behind functions to prevent errors
    ###############################################################################
    @ql.log_function()
    def module_exists(self, module_name: str) -> bool:
        '''
        returns True    : if module does currently exist in DB\n
        returns False   : if module does not exist in DB
        '''
        if self.index.get(module_name) == None:
            ql.log_general_message(f"Module {module_name} does not exist in ModuleDB")
            return False
        ql.log_general_message(f"Module {module_name} exists in ModuleDB")
        return True
    
    #______________________________________________________________________________
    @ql.log_function()
    def add_new_module(
            self,
            module_name:        str,
            author:             str     =   "developer_made",
            description:        str     =   "No Description Provided",
            subjects_covered:   list    =   [].copy(),
            concepts_covered:   list    =   [].copy(),
            question_ids:       list    =   [].copy()
            ):
        '''
        Abstraction, just encapsulates the QuestionModule constructor,
        If more functionality and verification is needed, its wrapped in this function and we can handle it here
        '''
        self.index[module_name] = QuestionModule(
            module_name         = module_name,
            author              = author,
            description         = description,
            subjects_covered    = subjects_covered,
            concepts_covered    = concepts_covered,
            questions           = question_ids
            )
        
    #______________________________________________________________________________
    @ql.log_function()
    def get_module_names(self):
        '''
        returns a view objects of all the module names that exist in Quizzer's QuestionModuleDB
        '''
        return list(self.index.keys())
    #______________________________________________________________________________
    @ql.log_function()
    def get_questions_by_module(self, module_name):
        if self.module_exists(module_name):
            ref = self.index[module_name]
            ref: QuestionModule
            return ref.questions.copy() # return a copy of the list, not a reference to it
        else:
            ql.log_warning(f"Attempted to access module that does not exist, returning an empty list")
            return []
        
    #______________________________________________________________________________
    @ql.log_function()
    def update_existing_module(
            self, module_name,
            author:             str         =   None,
            description:        str         =   None,
            subjects_covered:   list[str]   =   None, 
            concepts_covered:   list[str]   =   None, 
            questions:          list[str]   =   None
            ):
        '''
        Abstracts away some calls, updating the module if it exists
        '''

        ref = self.index[module_name]
        ref: QuestionModule
        ref.update_module(
            author              = author, 
            description         = description, 
            subjects_covered    = subjects_covered,
            concepts_covered    = concepts_covered,
            questions           = questions
            )
        ql.log_success_message(f"Updated Module {module_name} with Values:")
        ql.log_value("self.author", ref.author)
        ql.log_value("self.description", ref.description)
        ql.log_value("self.primary_subject", ref.primary_subject)
        ql.log_value("self.subjects_covered", ref.subjects_covered)
        ql.log_value("self.concepts_covered", ref.concepts_covered)
        ql.log_value("self.questions", ref.questions)
        ql.log_value("self.total_questions", ref.total_questions)


###############################################################################
###############################################################################
###############################################################################
class QuestionObjectDB():
    ###############################################################################
    # Cool Dunder Methods
    @ql.log_function()
    def __init__(self):
        self.__all_question_objects = {}.copy() # stored by id: QuestionObject
        self.__subject_index        = {}.copy() # {"subject_class": "question_id"}
        self.__concept_index        = {}.copy() # {"concept_class": "question_id"}
        self.__module_index         = QuestionModuleDB # {"module_name": "question_id"}

    @ql.log_function()
    def __add__(self, other):
        if isinstance(other, QuestionObject):
            # If use add operator DB + QuestionObject, should add the question object to the 
            self.add_new_QuestionObject(other)
        else:
            raise ValueError("May not add type {type(other)} to QuestionObjectDB \n May only add type QuestionObject through addition operator")
    ###############################################################################
    # Index build functions (compile into a single function)
    @ql.log_function()
    def _construct_sub_indices(self):
        '''
        Iterate over the database in order generate the indices\n
        Categorize questions by subject, concept, and module
        '''
        # verify the module_index in QuestionObjectDB is of instance QuestionModuleDB:
        if not isinstance(self.__module_index, QuestionModuleDB):
            self.__module_index = QuestionModuleDB()

        ql.log_general_message(f"Regenerating QuestionObjectDB indicies")
        subject_data = {}.copy()
        concept_data = {}.copy()
        module_data  = {}.copy()
        ql.log_value("subject_data", subject_data)
        ql.log_value("subject_data", concept_data)
        ql.log_value("subject_data", module_data)

        total_iterations = 0
        ql.log_value("total_iterations", total_iterations)
        # Single Pass Iteration for all data necessary:
        for question in self.__all_question_objects.values():
            # Error handling, build dictionary object dynamically, If the module hasn't been discovered initialize it in the dictionary with appropriate keys
            if module_data.get(question.module_name) == None:
                module_data[question.module_name] = {}.copy()
                module_data[question.module_name]["subjects"]       = [].copy()
                module_data[question.module_name]["concepts"]       = [].copy()
                module_data[question.module_name]["question_ids"]   = [].copy()

            total_iterations += 1 # Performance counter
            question: QuestionObject
            # Iterating over subjecst
            for subj in question.subjects:
                # Add the question id under it's subject label
                if subject_data.get(subj) == None:
                    subject_data[subj] = [].copy()
                subject_data[subj].append(question.id)
                # Add the subject under the module list of subjects
                module_data[question.module_name]["subjects"].append(subj)

            for conc in question.related_concepts:
                # Add the question id under it's concept label
                if concept_data.get(conc) == None:
                    concept_data[conc] = [].copy()
                concept_data[conc].append(question.id)
                # Add the concept under the module list of concepts
                module_data[question.module_name]["concepts"].append(conc)
            # Add the question id to the module list of question_id's
            module_data[question.module_name]["question_ids"].append(question.id)

        # Now we can write our collected data structure to our indices
        self.__subject_index = subject_data
        self.__concept_index = concept_data

        # Module index is a little bit more complicated, extra steps
        # Loop over the module_data we collected:
        for mod_name in module_data.keys():
            # module_exists function, while it does abstract the check, creates undo performance overhead
            # Check whether the module currently exists in the QuestionModuleDB
            ql.log_section_header(f"Updating ModuleDB -> Module_Name: {mod_name}")
            ql.log_value("subject_covered:", module_data[mod_name]["subjects"])
            ql.log_value("concepts_covered:",module_data[mod_name]["concepts"])
            ql.log_value("concepts_covered:",module_data[mod_name]["question_ids"])
            if not self.__module_index.module_exists(mod_name):
                # Initialize new QuestionModule add it directly
                self.__module_index.add_new_module(mod_name,
                                                   subjects_covered =   module_data[mod_name]["subjects"],
                                                   concepts_covered =   module_data[mod_name]["concepts"],
                                                   question_ids     =   module_data[mod_name]["question_ids"])
            else:
                # module does exist
                self.__module_index.update_existing_module(mod_name,
                                                   subjects_covered =   module_data[mod_name]["subjects"],
                                                   concepts_covered =   module_data[mod_name]["concepts"],
                                                   questions        =   module_data[mod_name]["question_ids"])


        ql.log_value("total_iterations", total_iterations)
    ###############################################################################
    # Index access functions
    ###############################################################################
    # Subject specific access
    @ql.log_function()
    def get_list_of_subjects(self):
        '''
        returns All subjects currently covered by Quizzer
        '''
        ql.log_value("all_subjects:", self.__subject_index.keys())
        return self.__subject_index.keys()
    
    @ql.log_function()
    def get_questions_by_subject(self, subject_name: str):
        '''
        returns all question ID's that correspond with a given subject_name.

        If you don't know what to query, use the get_list_of_subjects function to query all available options
        '''
        ql.log_general_message(f"Attempting to get all questions of subject: {subject_name}")
        ql.log_value("questions_by_subject", self.__subject_index[subject_name].copy())
        return self.__subject_index[subject_name].copy()
    #___________________________________
    # Concept specific access
    @ql.log_function()
    def get_list_of_concepts(self):
        ql.log_general_message(f"Attempting to get all concepts present in QuestionObjectDB")
        ql.log_value("list_of_concepts", self.__concept_index.keys())
        return self.__concept_index.keys()
    
    @ql.log_function()
    def get_questions_by_concept(self, concept_name: str) -> list:
        ql.log_general_message(f"Attempting to get all questions of concept: {concept_name}")
        ql.log_value("questions_by_concept", self.__subject_index[concept_name].copy())
        return self.__concept_index[concept_name].copy()
    #___________________________________
    # Module specific access
    @ql.log_function()
    def get_list_of_module_names(self):
        ql.log_general_message(f"Attempting to get all module names")
        ql.log_value("questions_by_concept", self.__module_index.get_module_names())
        return self.__module_index.get_module_names()
    
    @ql.log_function()
    def get_questions_by_module_name(self, module_name:str) -> list:
        '''
        returns a COPY of the list of question_id's belonging to the given module
        '''
        ql.log_general_message(f"Attempting to get all questions contained in module: {module_name}")
        ql.log_value("questions_by_module", self.__module_index.get_questions_by_module(module_name))
        return self.__module_index.get_questions_by_module(module_name)
    # End Index Access functionality
    ###############################################################################
    # Add or Delete QuestionObject's
    ###############################################################################
    @ql.log_function()
    def add_new_QuestionObject(self, question_object: QuestionObject):
        self.__all_question_objects[question_object.id] = question_object
        self._construct_sub_indices() # Rebuild the index whenever a question is added

    @ql.log_function()
    def delete_QuestionObject(self, question_object_id: str):
        del self.__all_question_objects[question_object_id]

    @ql.log_function()
    def get_QuestionObject(self, question_id: str) -> QuestionObject:
        try:
            return self.__all_question_objects[question_id]
        except KeyError as e:
            ql.log_error("Question does not exist:", e)
    
# End QuestionObjectDB
###############################################################################
class UserProfilesDB():
    ###############################################################################
    # Dunder Mifflin Paper Company!
    ###############################################################################
    @ql.log_function()
    def __init__(self):
        self.__profile_dict = {}.copy() # {email_address: file_name}
    
    ###############################################################################
    # Add, Remove, Load, Save User Profiles
    ###############################################################################
    @ql.log_function()
    def add_UserProfile(self,
                        username:               str,
                        email_address:          str,
                        full_name:              str,
                        tutorial_questions:     str | list,
                        list_of_all_modules:    list[str],
                        list_of_all_subjects:   list[str]
                        ):
        '''
        Mechanism by which we add a fresh UserProfile to QuizzerDB
        - Takes in the data required for the UserProfile Constructor, 
        username is the alias for the User's account, will be the name shared with other users
        email_address is the user's actual email address used for account signup
        full_name is the user's full real name, we take a full name instead of first and last, because some people have many names.
        '''
        ql.log_general_message(f"Adding New Profile {email_address}")
        # Ensure we are not creating a duplicate account
        existing_accounts = self.__profile_dict.keys()
        ql.log_value("existing_accounts", existing_accounts)
        if email_address in existing_accounts:
            return f"Error: email_address already exists in system"
        # Instantiate new instance of UserProfile
        new_profile = UserProfile(
            username            =   username,
            email_address       =   email_address,
            full_name           =   full_name,
            tutorial_questions  =   tutorial_questions,
            list_of_all_modules =   list_of_all_modules,
            list_of_all_subjects=   list_of_all_subjects
        )
        ql.log_general_message(f"New Profile Generating, now attempting to commit profile to file LTS (Long Term Storage)")
        # Immediately save that instance
        self.commit_UserProfile(new_profile)
        # Ensure we write the reference to the internal dictionary
        file_name = f"{email_address}.pickle"
        self.__profile_dict[email_address] = file_name
    #______________________________________________________________________________
    @ql.log_function()
    def remove_UserProfile(self, email_address):
        existing_accounts = self.__profile_dict.keys()
        if email_address in existing_accounts:
            ql.log_success_message(f"{email_address} exists, now being deleted. . .")
            del self.__profile_dict[email_address]
        else:
            ql.log_error(f"{email_address} does not exist in DB")
    
    #______________________________________________________________________________
    @ql.log_function()
    def get_all_profile_emails(self):
        ql.log_general_message("return value is a copy")
        return list(self.__profile_dict.keys())
    #______________________________________________________________________________
    @ql.log_function()
    def load_UserProfile(self, email_address) -> UserProfile:
        '''
        Mechanism by which we can LOAD in a user profile
        Loads the profile of the user with the provided email address
        Returns the reference to the loaded UserProfile
        '''
        # To save on memory costs on the API, the __profile_dict should just be a list of references to .pickle files, where the actual data is held. Note that the __profile_dict is of format {"email_address": "file_name.pickle"}
        import os
        existing_accounts = self.get_all_profile_emails()
        if email_address not in existing_accounts:
            ql.log_warning(f"Profile with {email_address} does not exist")
            return None
        src_dir = os.path.dirname(os.path.abspath(__file__))
        user_profiles_dir = os.path.join(src_dir, "user_profiles")
        file_name = f"{email_address}.pickle"
        full_path = os.path.join(user_profiles_dir, file_name)

        with open(full_path, "rb") as f:
            user_profile: UserProfile = pickle.load(f)
        return user_profile

    #______________________________________________________________________________
    @ql.log_function()
    def commit_UserProfile(self, profile_data: UserProfile):
        '''
        Mechanism by which we can save the current state of the UserProfile passed to it
        '''
        ql.log_general_message(f"Now Committing File:")
        import os
        src_dir = os.path.dirname(os.path.abspath(__file__))
        user_profiles_dir = os.path.join(src_dir, "user_profiles")
        email_address = profile_data.email_address
        file_name = f"{email_address}.pickle"
        full_path = os.path.join(user_profiles_dir, file_name)

        with open(full_path, "wb") as f:
            pickle.dump(profile_data, f, protocol=pickle.HIGHEST_PROTOCOL)
            ql.log_general_message(f"Saved Profile to {full_path}")

class QuizzerDB:
    @ql.log_function()
    def __init__(self):
        self.QuestionObjectDB = QuestionObjectDB()
        self.UserProfilesDB   = UserProfilesDB()

    @ql.log_function()
    def commit_QuizzerDB(self):
        import os
        import sys
        src_dir = os.path.dirname(os.path.abspath(__file__))
        file_name = "QuizzerDB.pickle"
        full_path = os.path.join(src_dir, file_name)
        with open(full_path, "wb") as f:
            pickle.dump(self, f, protocol=pickle.HIGHEST_PROTOCOL)
            ql.log_success_message(f"Wrote {file_name} to full_path: {full_path}")

    #FIXME
    # Need to convert the above load and commit to pass through functions, for easier access from the API
    ###############################################################################
    # Debug and Test Functions
    # Do not use these outside of test clients
    ###############################################################################
    @ql.log_function()
    def debug_write_UserProfiles_to_json(self):
        """
        Standalone function that writes detailed information about each UserProfile to separate JSON files.
        This function operates independently from the main DB debug functionality.
        Returns a list of the generated JSON filenames.
        """
        import json
        import datetime
        from json import JSONEncoder

        class CustomEncoder(JSONEncoder):
            def default(self, obj):
                if isinstance(obj, set):
                    return list(obj)
                if hasattr(obj, '__dict__'):
                    return obj.__dict__
                return str(obj)
        
        timestamp = datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
        profile_files = []
        all_profile_emails = self.UserProfilesDB.get_all_profile_emails()
        print(f"Writing {len(all_profile_emails)} user profiles to JSON files...")
        
        for email in all_profile_emails:
            try:
                # Load the profile
                profile = self.UserProfilesDB.load_UserProfile(email)
                
                # Create profile data structure
                profile_data = profile.__dict__               
                # Write to file with a clear naming convention
                profile_filename = f"user_profile_{email.replace('@', '_at_')}_{timestamp}.json"
                with open(profile_filename, 'w') as f:
                    json.dump(profile_data, f, indent=4, cls=CustomEncoder)
                
                profile_files.append(profile_filename)
                print(f"  Wrote profile for {email} to {profile_filename}")
                
            except Exception as e:
                print(f"Error processing profile {email}: {e}")
                self.UserProfilesDB.remove_UserProfile(email)
        
        print(f"Completed writing {len(profile_files)} user profiles to JSON files")
        return profile_files
    @ql.log_function()
    def debug_write_db_to_json(self):
        """
        Write complete database contents to a JSON file for debugging purposes.
        Creates a comprehensive debug representation of the entire QuizzerDB.
        """        
        import json
        import datetime
        from json import JSONEncoder

        class CustomEncoder(JSONEncoder):
            def default(self, obj):
                if isinstance(obj, set):
                    return list(obj)
                if hasattr(obj, '__dict__'):
                    return obj.__dict__
                return str(obj)
        
        # Create comprehensive debug representation of the database
        debug_data = {
            "metadata": {
                "timestamp": datetime.datetime.now().isoformat(),
            },
            "question_db": {
                "questions": {},
                "modules": {},
                "subject_index": {},
                "concept_index": {}
            },
            "user_profiles_db": {
                "profiles": {}
            }
        }

        # Adding QuestionObjectDB data
        question_db = self.QuestionObjectDB
        
        # Using the name mangling pattern to access private variables
        all_questions = question_db._QuestionObjectDB__all_question_objects
        subject_index = question_db._QuestionObjectDB__subject_index
        concept_index = question_db._QuestionObjectDB__concept_index
        module_index = question_db._QuestionObjectDB__module_index
        
        # Add metadata
        debug_data["question_db"]["metadata"] = {
            "total_questions": len(all_questions),
            "total_modules": len(list(question_db.get_list_of_module_names())),
            "total_subjects": len(list(question_db.get_list_of_subjects())),
            "total_concepts": len(list(question_db.get_list_of_concepts()))
        }
        
        # Add questions data
        for question_id, question_obj in all_questions.items():
            debug_data["question_db"]["questions"][question_id] = question_obj.__dict__
        
        # Add subject index
        for subject, question_id in subject_index.items():
            debug_data["question_db"]["subject_index"][subject] = question_id
        
        # Add concept index
        for concept, question_id in concept_index.items():
            debug_data["question_db"]["concept_index"][concept] = question_id
        
        # Add modules data
        for module_name in question_db.get_list_of_module_names():
            module_obj = module_index.index.get(module_name)
            if module_obj:
                debug_data["question_db"]["modules"][module_name] = {
                    "name": module_obj.module_name,
                    "author": module_obj.author,
                    "description": module_obj.description,
                    "primary_subject": module_obj.primary_subject,
                    "subjects_covered": list(module_obj.subjects_covered) if isinstance(module_obj.subjects_covered, set) else module_obj.subjects_covered,
                    "concepts_covered": list(module_obj.concepts_covered) if isinstance(module_obj.concepts_covered, set) else module_obj.concepts_covered,
                    "total_questions": module_obj.total_questions,
                    "questions": module_obj.questions
                }
        
        # Adding UserProfilesDB data
        user_profiles_db = self.UserProfilesDB
        profile_dict = user_profiles_db._UserProfilesDB__profile_dict
        
        debug_data["user_profiles_db"]["metadata"] = {
            "total_profiles": len(profile_dict)
        }
        
        for email, filename in profile_dict.items():
            debug_data["user_profiles_db"]["profiles"][email] = {
                "filename": filename
            }

        # Generate filename with timestamp
        timestamp = datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = f"quizzer_db_debug_{timestamp}.json"
        
        # Write to file with custom encoder and formatting
        with open(filename, 'w') as f:
            json.dump(debug_data, f, indent=4, cls=CustomEncoder)
        
        print(f"Complete QuizzerDB debug data written to {filename}")
        return filename
    
@ql.log_function()    
def load_quizzer_db() -> QuizzerDB:
    '''
    Loads the existing DB into memory and returns its reference
    '''
    import os
    src_dir = os.path.dirname(os.path.abspath(__file__))
    ql.log_value("src_dir:", src_dir)
    file_name = "QuizzerDB.pickle"
    full_path = os.path.join(src_dir, file_name)
    with open(full_path, "rb") as f:
        db: QuizzerDB = pickle.load(f)
        print(f"Successfully loaded DB from {full_path}")

    db.QuestionObjectDB._construct_sub_indices()
    return db

