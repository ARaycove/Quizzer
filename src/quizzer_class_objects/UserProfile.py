import pandas as pd
import pickle
from UserQuestionObject import UserQuestionObject
from QuestionObject     import QuestionObject
# class DotDict(dict):
#     """
#     Dictionary subclass that allows attribute-style access (dot notation)
#     while maintaining all standard dictionary functionality.
    
#     Examples:
#         >>> d = DotDict({'a': 1, 'b': {'c': 2}})
#         >>> d.a  # Access with dot notation
#         1
#         >>> d.b.c  # Works with nested dictionaries
#         2
#         >>> d.b['c']  # Standard dictionary access still works
#         2
#         >>> d.new_key = 'value'  # Can set new values with dot notation
#         >>> d
#         {'a': 1, 'b': {'c': 2}, 'new_key': 'value'}
#     """
#     def __init__(self, *args, **kwargs):
#         super().__init__(*args, **kwargs)
#         # Convert nested dictionaries to DotDict instances
#         self._convert_nested_dicts()
    
#     def _convert_nested_dicts(self):
#         """Convert nested dictionaries to DotDict instances."""
#         for key, value in self.items():
#             if isinstance(value, dict) and not isinstance(value, DotDict):
#                 self[key] = DotDict(value)
    
#     def __getattr__(self, key):
#         """Allow attribute access for dictionary keys."""
#         try:
#             return self[key]
#         except KeyError:
#             raise AttributeError(f"'{self.__class__.__name__}' object has no attribute '{key}'")
    
#     def __setattr__(self, key, value):
#         """Allow setting dictionary keys via attributes."""
#         self[key] = value
        
#         # If we've added a dict, convert it to DotDict
#         if isinstance(value, dict) and not isinstance(value, DotDict):
#             self[key] = DotDict(value)
    
#     def __delattr__(self, key):
#         """Allow deleting keys via attributes."""
#         try:
#             del self[key]
#         except KeyError:
#             raise AttributeError(f"'{self.__class__.__name__}' object has no attribute '{key}'")
    
#     def __dir__(self):
#         """Enable auto-completion in IDEs and the REPL."""
#         return list(self.keys()) + dir(dict)
    
#     def update(self, *args, **kwargs):
#         """Override update to handle nested dictionaries."""
#         super().update(*args, **kwargs)
#         self._convert_nested_dicts()
#         return self
    
#     def copy(self):
#         """Return a new DotDict with the same items."""
#         return DotDict(super().copy())
    
#     def __repr__(self):
#         """Show class name for clearer debugging."""
#         items = ', '.join(f"{k!r}: {v!r}" for k, v in self.items())
#         return f"{self.__class__.__name__}({{{items}}})"

class UserProfileQuestionDB():
    '''
    Subclass to store all UserQuestionObjects
    '''
    def __init__ (self):
        self.__user_question_index = {}.copy()
        self.__review_schedule = {
            "reserve_bank": [],
            "deactivated": []
        }.copy()
    def __str__(self):
        full_print = "\n"
        for key, value in self.__user_question_index.items():
            full_print += f"    {key:25}: {value}" 
        return full_print
    # Abstracted functionality
    def get_num_questions(self):
        return len(self.__user_question_index)
    
    def add_question(self, question_object: QuestionObject):
        self.__user_question_index[question_object.id] = UserQuestionObject(question_object)
        self.__review_schedule["reserve_bank"].append(question_object.id)


    # Debug Utils
    def print_review_schedule(self):
        print(self.__review_schedule)


class UserProfileSettingsDB:
    '''
    Subclass to store all User Settings
    '''
    pass
    # Could potentionally make a sub-subclass called setting
class UserProfileStatsDB:
    '''
    Subclass to storre all User statistics
    '''
    pass

class UserProfile:
    '''
    Quizzer Storage Object for all User data,
    new instances of UserProfile will be generated for every user
    User Profiles are broken down into three sections
    - Questions
        - In-circulation questions
        - Reserve Questions (not yet introduced but eligible to be introduced)
        - Deactivated Questions (as disabled by the user, either individually or through disabling a module)
    - Settings
        - Allows the user to alter the behavior of Quizzer to adapt to individual preferences
    - Stats
        - Holds a majority of User data, primarily usage data, that is not directly related to a user's history with an individual question.
        - There are additional stats held for individual questions, showing the users individual usage history with each question they introduced to.
    '''
    # Commentary
    #     Design Pattern: To be saved as individual files, while the main QuizzerDB class will load in these individual files as necessary. Saving each profile as an individual file should allow for more optimal memory management. If Quizzer contains 1000 profiles and only 50-100 users are active at any given time then we only need to load in 50-100 user profiles into memory at any given time
    ###################################
    # Core Dunder Methods
    def __init__(self,
                 username:          str,
                 email_address:     str,
                 first_name:        str,
                 last_name:         str, 
                 user_questions =   UserProfileQuestionDB(), 
                 user_settings  =   UserProfileSettingsDB(),
                 user_stats     =   UserProfileStatsDB(),
                 ):
        self.user_questions: UserProfileQuestionDB  = user_questions
        self.user_settings: UserProfileSettingsDB   = user_settings
        self.user_stats: UserProfileStatsDB         = user_stats
        self.username                               = username
        self.email_address: str                     = email_address
        self.first_name                             = first_name
        self.last_name                              = last_name

    def __str__(self):
        full_print = ""
        for key, value in self.__dict__.items():
            full_print += f"{key:25}: {value}\n"
        return full_print
    ###################################
    # Properties
    @property
    def num_questions(self):
        return self.user_questions.get_num_questions()
    
    ###################################
    # Core Functions (API)
    def add_question_to_UserProfile(self, question_object: QuestionObject):
        self.user_questions.add_question(question_object) # This is purely an abstraction for easier calling from main program
        # self.add_question_to_UserProfile as opposed to self.user_questions.add_question, call is shorter as a result

    def save_UserProfile(self):
        with open(f"{self.email_address}_QuizzerUserProfile.pickle", "wb") as f:
            pickle.dump(self, f, protocol=pickle.HIGHEST_PROTOCOL)

if __name__ == "__main__":
    print(f"Loading in test_objects")
    with open("TestQuestionObject.pickle", "rb") as f:
        test_question_object = pickle.load(f)

    test_profile = UserProfile("aacra0820@gmail.com", "Aaron", "Raycove")
    print("Testing __str__ printout of object UserProfile")
    print(test_profile)
    print(f"Testing Adding new Question to UserProfile. . .")
    test_profile.add_question_to_UserProfile(test_question_object)
    if test_profile.num_questions == 1:
        print("    Success")
    test_profile.user_questions.print_review_schedule()

    test_profile.save_UserProfile()




    