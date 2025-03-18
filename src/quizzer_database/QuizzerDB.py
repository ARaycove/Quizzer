import sys
import os
# Fixes the module import issue
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from quizzer_database.UserProfile import UserProfile, QuestionObject
from quizzer_database.DB_utils import util_QuizzerV4ObjDict_to_QuestionObject
import pickle


class QuestionObjectDB():
    ###############################################################################
    # Cool Dunder Methods
    def __init__(self):
        self.__all_question_objects = {}.copy() # stored by id: QuestionObject
        self.__subject_index        = {}.copy() # {"subject_class": "question_id"}
        self.__concept_index        = {}.copy() # {"concept_class": "question_id"}
        self.__module_index         = {}.copy() # {"module_name": "question_id"}
    def __add__(self, other):
        if isinstance(other, QuestionObject):
            # If use add operator DB + QuestionObject, should add the question object to the 
            self.add_new_QuestionObject(other)
        else:
            raise ValueError("May not add type {type(other)} to QuestionObjectDB \n May only add type QuestionObject through addition operator")
    ###############################################################################
    # Index build functions (compile into a single function)
    def _construct_sub_indices(self):
        '''
        Iterate over the database in order generate the indices
        '''
        # FIXME need to add in efficiency, cache values and only recalculate indices when new questions are added
        subject_index = {}.copy()
        concept_index = {}.copy()
        module_index  = {}.copy()
        for question in self.__all_question_objects.values():
            question: QuestionObject
            for subj in question.subjects:
                subject_index.update({subj: question.id}) # add this id under that subject label
            for conc in question.related_concepts:
                concept_index.update({conc: question.id}) # add each concept under that concept label
            module_index.update({question.module_name: question.id})
    ###############################################################################
    # Index access functions
    ###############################################################################
    # Subject specific access
    def get_list_of_subjects(self):
        '''
        returns All subjects currently covered by Quizzer
        '''
        return self.__subject_index.keys()
    
    def get_questions_by_subject(self, subject_name: str):
        '''
        returns all question ID's that correspond with a given subject_name.

        If you don't know what to query, use the get_list_of_subjects function to query all available options
        '''
        raise NotImplementedError("I'm not done yet, calm down")
    #___________________________________
    # Concept specific access
    def get_list_of_concepts(self):
        return self.__concept_index.keys()
    
    def get_questions_by_concept(self, concept_name: str):
        raise NotImplementedError("I'm not done yet, calm down")
    #___________________________________
    # Module specific access
    def get_list_of_module_names(self):
        return self.__module_index.keys()
    
    def get_questions_by_module_name(self, module_name:str):
        raise NotImplementedError("I'm not done yet, calm down")
    # End Index Access functionality
    ###############################################################################
    # Add or Delete QuestionObject's
    ###############################################################################
    def add_new_QuestionObject(self, question_object: QuestionObject):
        self.__all_question_objects[question_object.id] = question_object

    def delete_QuestionObject(self, question_object_id: str):
        del self.__all_question_objects[question_object_id]

    def get_QuestionObject(self, question_id: str) -> QuestionObject:
        return self.__all_question_objects[question_id]

    ###############################################################################
    # Debug and Test Functions
    # Do not use these outside of test clients
    ###############################################################################
    def debug_write_db_to_json(self):
        """
        Write database contents to a JSON file for debugging purposes.
        Creates a debug representation of all question objects.
        """        
        import json
        import datetime
        # Create debug representation of the database
        debug_data = {
            "timestamp": datetime.datetime.now().isoformat(),
            "total_questions": len(self.__all_question_objects),
            "questions": {}
        }
        for question_id, question_obj in self.__all_question_objects.items():
            # Extract key properties for debugging
            question_obj: QuestionObject
            question_data = question_obj.__dict__
            debug_data["questions"][question_id] = question_data
        
        # Generate filename with timestamp
        timestamp = datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = f"questiondb_debug_{timestamp}.json"
        
        with open(filename, 'w') as f:
            json.dump(debug_data, f, indent=4)
        
        print(f"Debug data written to {filename}")
        return filename
    
# End QuestionObjectDB
###############################################################################
class UserProfilesDB():
    def __init__(self):
        self.__profile_dict = {str: str}.copy()
    
    def add_UserProfile(self,
                        username: str,
                        email_address: str,
                        full_name: str
                        ):
        '''
        Mechanism by which we add a fresh UserProfile to QuizzerDB
        - Takes in the data required for the UserProfile Constructor, 
        username is the alias for the User's account, will be the name shared with other users
        email_address is the user's actual email address used for account signup
        full_name is the user's full real name, we take a full name instead of first and last, because some people have many names.
        '''
        new_profile = UserProfile(
            username        =   username,
            email_address   =   email_address,
            full_name       =   full_name
        )
        self.__profile_dict[email_address] = f"{email_address}.pickle"
        with open(f"{email_address}.pickle", "wb"):
            pickle.dump(new_profile, f, protocol=pickle.HIGHEST_PROTOCOL)

    def load_UserProfile(self):
        '''
        Mechanism by which we can LOAD in a user profile
        '''
        # To save on memory costs on the API, the __profile_dict should just be a list of references to .pickle files, where the actual data is held. Note that the __profile_dict is of format {"email_address": "file_name.pickle"}
        pass #FIXME

    def commit_UserProfile(self):
        '''
        Mechanism by which we can save the current state of the UserProfile passed to it
        '''
        # FIXME

class QuizzerDB:
    
    def __init__(self):
        self.QuestionObjectDB = QuestionObjectDB()
        self.UserProfilesDB   = UserProfilesDB()

    def commit_QuizzerDB(self):
        with open("QuizzerDB.pickle", "wb") as f:
            pickle.dump(self, f, protocol=pickle.HIGHEST_PROTOCOL)

    #FIXME
    # Need to convert the above load and commit to pass through functions, for easier access from the API

    
def load_quizzer_db():
    '''
    Loads the existing DB into memory and returns its reference
    '''
    import os
    # Get the directory where this module is located
    module_dir = os.path.dirname(os.path.abspath(__file__))
    # Path options to try
    paths_to_try = [
        os.path.join(module_dir, "QuizzerDB.pickle"),        # Same directory as module
        os.path.join(os.path.dirname(module_dir), "QuizzerDB.pickle")  # Parent directory
    ]

    for path in paths_to_try:
        try:
            with open(path, "rb") as f:
                db = pickle.load(f)
                print(f"Successfully loaded DB from {path}")
                return db
        except FileNotFoundError:
            continue
    
    raise FileNotFoundError("QuizzerDB.pickle not found in any expected locations")
            


###############################################################################
# Begin Test Client
###############################################################################
if __name__ == "__main__":
    import json
    print("Testing QuizzerDB Implementation")
    # Create a QuizzerDB instance
    db = QuizzerDB()

    # Run the following comment to conver the old db to the new db
    with open("../system_data/question_object_data.json", "r") as f:
        old_data:dict = json.load(f)
        print(f"Old Data loaded successfully. . .\n Now applying util function to all question objects in old data")
    i = 0
    for key, value in old_data.items():
        try:
            qo = util_QuizzerV4ObjDict_to_QuestionObject(value)
            i += 1
            db.QuestionObjectDB.add_new_QuestionObject(qo)
        except:
            print(f"conversion failed on id: {key:.50}")

    db.commit_QuizzerDB()

    with open("QuizzerDB.pickle", "rb") as f:
        db = pickle.load(f)
    db: QuizzerDB
    db.QuestionObjectDB.debug_write_db_to_json()

