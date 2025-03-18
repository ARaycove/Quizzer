import pandas as pd
import pickle
from UserQuestionObject import UserQuestionObject
from QuestionObject     import QuestionObject
# FIXME Need some sort of mechanism to prevent a question that has just been answered from immediatley appearing again. For example if the user answers something incorrectly, it should not be immediately shown again. If it is selected by the algorithm the algorithm should "try again", If it's the only question left, then it should just get more questions and add them into circulation.

# FIXME Next question selection
#   What if we gave a mechanism for users to enter questions they have as they use Quizzer? Quizzer could then use this list of questions to determine what comes next, otherwise defaulting to a standard algorithm. This would allow Quizzer to be even more personlized based on exactly what the user is curious about. We would have to match those user questions to the database for likelihood, if no match found, then we'll need to add them

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




    