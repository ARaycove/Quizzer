import pandas as pd
from datetime import datetime, date, timedelta
import pickle
import uuid
from quizzer_database.user_question_object    import UserQuestionObject
from quizzer_database.question_object        import QuestionObject
# FIXME Need some sort of mechanism to prevent a question that has just been answered from immediatley appearing again. For example if the user answers something incorrectly, it should not be immediately shown again. If it is selected by the algorithm the algorithm should "try again", If it's the only question left, then it should just get more questions and add them into circulation.

# FIXME Next question selection
#   What if we gave a mechanism for users to enter questions they have as they use Quizzer? Quizzer could then use this list of questions to determine what comes next, otherwise defaulting to a standard algorithm. This would allow Quizzer to be even more personlized based on exactly what the user is curious about. We would have to match those user questions to the database for likelihood, if no match found, then we'll need to add them

class UserProfileQuestionDB():
    '''
    Subclass to store all UserQuestionObjects
    '''
    ###############################################################################
    # Dunder Mifflin Methods O_O
    ###############################################################################
    def __init__ (self, tutorial_questions):
        self.__user_question_index = {}.copy()
        self.__review_schedule = {
            "reserve_bank": [],
            "deactivated": []
        }.copy()
        self.add_initial_tutorial_questions(tutorial_questions)

    def __str__(self):
        full_print = "\n"
        for key, value in self.__user_question_index.items():
            full_print += f"    {key:25}: {value}" 
        return full_print
    ###############################################################################
    # Abstracted functionality
    ###############################################################################
    def get_num_questions(self):
        return len(self.__user_question_index)

    ###############################################################################
    # Add Remove Questions from Profile
    ###############################################################################
    def add_initial_tutorial_questions(self, tutorial_questions: list[str]):
        '''
        In order to add our tutorial questions we'll need the list of question_id's that correspond to our tutorial module
        tutorial_questions: list of question.id strings
        '''
        if isinstance(tutorial_questions, str):
            self.add_question(tutorial_questions)
            self.place_question_into_circulation(tutorial_questions)
        else:
            for question_id in tutorial_questions:
                self.add_question(question_id)
                self.place_question_into_circulation(question_id)
    
    #______________________________________________________________________________
    def add_question(self, question_id: str):
        '''
        add a question into the User's QuestionDB
        If the question is the tutorial questions we need to place it directly into circulation rather than the reserve bank

        The default column of the review_schedule is the reserve_bank
        '''
        self.__user_question_index[question_id] = UserQuestionObject(question_id)
        user_question: UserQuestionObject = self.__user_question_index[question_id]
        user_question.activate_question() # ensure is active
        self.__review_schedule["reserve_bank"].append(question_id)

    # Logic for how questions are stored and retrieved, Yes for you the person who has no idea what's going on.
    # Questions are placed into one of three* locations: the reserve_bank key,the deactivated key, or a key with a date as the column, the number of these keys will be quite lengthy once a user gets 'rolling'. This allows us to grab questions by due date, so when evaluating what questions we are going to show the user at any moment in time, we only need to grab questions under todays date, or yesterday and behind if the user is behind
    #______________________________________________________________________________
    def _util_remove_question_from_column(self, question_id):
        '''
        Just here to clean up duplicate code, and simplify error handling
        '''
        current_location = self._question_column_loc(question_id)
        # print(f"    Should be in {current_location}")
        self.__review_schedule[current_location].remove(question_id)
        # In case that column is a date and is empty, we'll clean it up
        if current_location not in ["deactivated", "reserve_bank"] and len(self.__review_schedule[current_location]) == 0:
            del self.__review_schedule[current_location]

    #______________________________________________________________________________
    def _util_add_question_to_column(self, question_id):
        '''
        Just here to clean up duplicate code, and simplify error handling
        '''
        current_location = self._question_column_loc(question_id)
        # print(f"    Should be go in {current_location}")
        try: # date_key might not exist
            self.__review_schedule[current_location].append(question_id)
        except:
            self.__review_schedule[current_location] = [question_id] # initialize new list column with single id in it

    #______________________________________________________________________________
    def _question_column_loc(self, question_id):
        '''
        Internal function that returns the name of the column where the question should be
        '''
        user_question: UserQuestionObject = self.__user_question_index[question_id]
        if not user_question.is_active:
            return str("deactivated")
        # If reach here, question is active, now check whether is_circulating now
        elif user_question.in_circulation: # question is circulating and active, place into appropriately dated column
            # questions marked in circulation will be active
            date_due = user_question.next_revison_due
            date_due = date_due.replace().date()
            return str(date_due)
        else: # question is active, but not marked to circulate, place into reserve_bank
            return str("reserve_bank")

    #______________________________________________________________________________
    def place_question_into_circulation(self, question_id):
        # print(f"Placing Question Into Circulation")
        user_question: UserQuestionObject = self.__user_question_index[question_id]
        # General pattern:
        #   Erase from one column and place into a different one
        self._util_remove_question_from_column(question_id)
        user_question.place_into_circulation()  # flips the boolean, indicating it is no longer in circulation
        user_question.activate_question()       # flips the boolean, indicating the question is now active and eligble to be placed into circulation
        self._util_add_question_to_column(question_id)


    #______________________________________________________________________________
    def remove_question_from_circulation(self, question_id):
        print(f"Removing Question from circulation")
        user_question: UserQuestionObject = self.__user_question_index[question_id]
        self._util_remove_question_from_column(question_id)
        user_question.remove_from_circulation() # flips the boolean, indicating it is now in circulation
        self._util_add_question_to_column(question_id)

    #______________________________________________________________________________
    def deactive_question(self, question_id):
        user_question: UserQuestionObject = self.__user_question_index[question_id]
        self._util_remove_question_from_column(question_id)
        user_question.deactivate_question()     # flips the boolean, indicating it should go in the deactivated key
        self._util_add_question_to_column(question_id)

    #______________________________________________________________________________
    def reactivate_question(self, question_id):
        user_question: UserQuestionObject = self.__user_question_index[question_id]
        self._util_remove_question_from_column(question_id)
        # If the question was circulating at time of deactivation, it will still be in circulation when this is called
        user_question.activate_question()       # flips the boolean, question is eligible to be placed into circulation
        self._util_add_question_to_column(question_id)

    ###############################################################################
    # Debugging Statements
    ###############################################################################
    # Debug Utils
    def print_review_schedule(self):
        print(self.__review_schedule)


class UserProfileSettingsDB:
    '''
    Subclass to store all User Settings
    Subject Settings: (Also known as interest settings)
        -subject_name: { FIXME might just decide to turn this into a just interest and priority, and aggregate the rest into the stats block, but this is the stats used by our circulate algorithm
            interest_level: int,
            priority:       int,
            total_questions:int,
            num_in_circulation: int,
            total_activated:int,
            has_available_questions: bool}
    Module Settings:
        -New Modules Active By Default: bool
        -Module Status
            -module_name: bool

    Scrapping the following settings:
    quiz_length                 : Not needed, questions are selected one at a time based on an algorithm and full length quizzes are not populated
    "time_between_revisions"    : User should not have access to this, too advanced of functionality
    "due_date_sensitivity"      : User should also not have access to this, 
    "vault_path"                : A relic from QuizzerV1 and V2
    "desired_daily_questions"   : Fundamental change to when in_circulation algorithm is triggered, making this function not useful
    '''
    pass
    # Could potentionally make a sub-subclass called setting
class UserProfileStatsDB:
    '''
    Subclass to store all User statistics\n
    Stats to Included (FIXME if not implemented)\n
    All stats are historical records over time: properties are made to get just todays stat\n

    "current_eligible_questions":                       FIXME\n
    "reserve_questions_exhaust_in_x_days":              FIXME\n
    "non_circulating_questions":                        FIXME\n
    "Graphical Charts":                                 FIXME\n
    "average_num_questions_entering_circulation_daily": FIXME\n
    current_num_question_in_circulation:                FIXME\n
    total_in_circulation_questions_history:             FIXME\n
    "revision_streak_stats":                            FIXME\n
    "total_questions_in_database"(historical):          FIXME\n
    "average_questions_per_day":                        FIXME\n
    "total_questions_answered":                         FIXME\n
        This one can be verified by the attempt history
    ""questions_answered_by_date":                      FIXME\n

    '''
    pass
    # Some stats are derived, others are stored.



class UserProfile:
    '''
    Quizzer Storage Object for all User data,
    new instances of UserProfile will be generated for every user
    User Profiles are broken down into three sections
    - Questions
        - Must pass in current tutorial questions from QuizzerDB to instantiate a new Profile
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
                 full_name:         str,
                 tutorial_questions:str,
                 user_settings  =   UserProfileSettingsDB(),
                 user_stats     =   UserProfileStatsDB(),
                 ):
        self.user_uuid                              = self.generate_uuid()
        self.user_questions: UserProfileQuestionDB  = UserProfileQuestionDB(tutorial_questions)
        self.user_settings: UserProfileSettingsDB   = user_settings
        self.user_stats: UserProfileStatsDB         = user_stats
        self.username                               = username
        self.email_address: str                     = email_address
        self.full_name                              = full_name

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
    def generate_uuid(self):
        '''
        Every user will have a Unique Universal ID (UUID) assigned upon profile creation
        '''
        return str(uuid.uuid4())
    
    def add_question_to_UserProfile(self, question_id: str):
        self.user_questions.add_question(question_id) # This is purely an abstraction for easier calling from main program
        # self.add_question_to_UserProfile as opposed to self.user_questions.add_question, call is shorter as a result

    def _verify_stats(self):
        '''
        Goes through and ensures all stats are sorted and no missing values/dates exist (should only need to be called once upon being loaded)

        Ensure date stats are sorted chronologically, ensure missing values, if the user missed a day or two or three, they'll need to be filled in

        Any verifiable stats, like the total number of attempts made (total questions answered) can be verified by summation of attempt objects, among other verifiable stats

        All other stats can be incremented while operating, Again this function should only be ran upon intialization
        '''
        raise NotImplementedError("Not done Yet")
    
if __name__ == "__main__":
    print(f"Test Client Currently Broken")




    