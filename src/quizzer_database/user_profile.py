import pandas as pd
from lib        import helper
from lib        import quizzer_logger as ql
from datetime   import datetime, date, timedelta
from typing     import Callable
from typing     import Dict, Union
import pickle
import logging
import uuid
import sys
import os
# Add parent directory to path so we can import properly
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from quizzer_database.user_question_object  import UserQuestionObject
from quizzer_database.question_object       import QuestionObject
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
    @ql.log_function()
    def __init__ (self, tutorial_questions):
        #---------------
        self.__user_question_index: Dict[str, UserQuestionObject] = {}.copy()
        # This should be empty upon initializing for the first time:
        ql.log_general_message("Initial UserProfileQuestionDB should be empty")
        if not self.__user_question_index:
            ql.log_success_message(f"Initial Index is: {self.__user_question_index}")
        else:
            ql.log_error(f"Initial UserProfile question index is not empty!")
            ql.log_value("__user_question_index", self.__user_question_index)
            raise Exception("Crashing Program, question_index should be empty")
        #---------------
        self.__review_schedule = {
            "reserve_bank": [],
            "deactivated": []
        }.copy()

        # Review Schedule should also be empty upon first intialization
        ql.log_general_message("Initial Review Schedule should be empty")
        if not self.__review_schedule:
            ql.log_success_message(f"Initial Review schedule is: {self.__review_schedule}")
        else:
            ql.log_error(f"Initial review schedule is not empty, should be empty")
            ql.log_value('__review_schedule:', self.__review_schedule)
            raise Exception("Crashing Program, review_schedule should be empty")
        #---------------
        # We should be adding the tutorial questions immediately
        self.add_initial_tutorial_questions(tutorial_questions)
        # The review schedule should have updated
        ql.log_general_message("Review Schedule should now have tutorial questions in circulation under date header")
        if self.__review_schedule and self.__user_question_index:
            ql.log_success_message("Review Schedule is no longer empty")
            ql.log_success_message("User Question Index is no longer empty")
            ql.log_value("__review_schedule", self.__review_schedule)
            ql.log_value("__user_question_index", self.__user_question_index)
        elif not self.__review_schedule:
            ql.log_error(f"review_schedule did not update with tutorial questions")
            ql.log_value('__review_schedule:', self.__review_schedule)
            ql.log_value("__user_question_index", self.__user_question_index)
            raise Exception("Crashing Program, add_initial_tutorial_questions did not function properly")
        

    @ql.log_function()
    def __str__(self):
        # No need to log this
        full_print = "\n"
        for key, value in self.__user_question_index.items():
            full_print += f"    {key:25}: {value}" 
        return full_print

    ###############################################################################
    # Add Remove Questions from Profile
    ###############################################################################
    @ql.log_function()
    def add_initial_tutorial_questions(self, tutorial_questions: list[str]):
        '''
        In order to add our tutorial questions we'll need the list of question_id's that correspond to our tutorial module
        tutorial_questions: list of question.id strings
        '''
        #---------------
        ql.log_general_message("Tutorial questions should have been passed as a list of question_id's")
        ql.log_value("tutorial_questions", tutorial_questions)

        if isinstance(tutorial_questions, str):
            ql.log_general_message("Only a single question_id was passed")
            self.add_question(tutorial_questions)
            self.place_question_into_circulation(tutorial_questions)
        else:
            ql.log_general_message("Iterating over Tutorial Questions, adding, and placing them into UserProfile circulation")
            for question_id in tutorial_questions:
                self.add_question(question_id)
                self.place_question_into_circulation(question_id)
    
    #______________________________________________________________________________
    @ql.log_function()
    def add_question(self, question_id: str):
        '''
        add a question into the User's QuestionDB
        If the question is the tutorial questions we need to place it directly into circulation rather than the reserve bank

        The default column of the review_schedule is the reserve_bank
        '''
        #---------------
        # add and update:
        ql.log_value("question_id:", question_id)
        self.__user_question_index[question_id] = UserQuestionObject(question_id)
        user_question: UserQuestionObject = self.__user_question_index[question_id]
        user_question.activate_question() # ensure is active
        self.__review_schedule["reserve_bank"].append(question_id)
        ql.log_success_message(f"Added question_id: {question_id} with exceptions")

    # Logic for how questions are stored and retrieved, Yes for you the person who has no idea what's going on.
    # Questions are placed into one of three* locations: the reserve_bank key,the deactivated key, or a key with a date as the column, the number of these keys will be quite lengthy once a user gets 'rolling'. This allows us to grab questions by due date, so when evaluating what questions we are going to show the user at any moment in time, we only need to grab questions under todays date, or yesterday and behind if the user is behind
    #______________________________________________________________________________
    @ql.log_function()
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
    @ql.log_function()
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
    @ql.log_function()
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
            return str(date_due.date())
        else: # question is active, but not marked to circulate, place into reserve_bank
            return str("reserve_bank")

    #______________________________________________________________________________
    @ql.log_function()
    def place_question_into_circulation(self, question_id):
        # print(f"Placing Question Into Circulation")
        user_question: UserQuestionObject = self.__user_question_index[question_id]
        # General pattern:
        #   Erase from one column and place into a different one
        self._util_remove_question_from_column(question_id)
        user_question.place_into_circulation()  # flips the boolean, indicating it should actively circulate
        user_question.activate_question()       # flips the boolean, indicating the question is now active and eligible to be placed into circulation
        self._util_add_question_to_column(question_id)


    #______________________________________________________________________________
    @ql.log_function()
    def remove_question_from_circulation(self, question_id):
        print(f"Removing Question from circulation")
        user_question: UserQuestionObject = self.__user_question_index[question_id]
        self._util_remove_question_from_column(question_id)
        user_question.remove_from_circulation() # flips the boolean, indicating it should not be in circulation
        self._util_add_question_to_column(question_id)

    #______________________________________________________________________________
    @ql.log_function()
    def deactive_question(self, question_id):
        user_question: UserQuestionObject = self.__user_question_index[question_id]
        self._util_remove_question_from_column(question_id)
        user_question.deactivate_question()     # flips the boolean, indicating it should go in the deactivated key
        self._util_add_question_to_column(question_id)

    #______________________________________________________________________________
    @ql.log_function()
    def reactivate_question(self, question_id):
        user_question: UserQuestionObject = self.__user_question_index[question_id]
        self._util_remove_question_from_column(question_id)
        # If the question was circulating at time of deactivation, it will still be in circulation when this is called
        user_question.activate_question()       # flips the boolean, question is eligible to be placed into circulation
        self._util_add_question_to_column(question_id)
    ###############################################################################
    # Question Selection
    ###############################################################################
    #______________________________________________________________________________
    @ql.log_function()
    def get_specific_UserQuestionObject(self, question_id) -> UserQuestionObject:
        return self.__user_question_index.get(question_id)
    
    #______________________________________________________________________________
    @ql.log_function()
    def select_next_question_for_review(self):
        ql.log_error("Question Selection Not Implemented")
        pass
    ###############################################################################
    # Debugging Statements
    ###############################################################################
    # Debug Utils
    #______________________________________________________________________________
    @ql.log_function()
    def get_review_schedule(self) -> Dict[str, list]:
        '''Returns a copy of the review schedule'''
        return self.__review_schedule.copy()
    
    @property
    def total_questions_in_profile(self):
        return len(self.__user_question_index)

class UserSetting:
    """
    Quizzer class object for individual settings (this designed to be a non-nested single setting)
    - May be nested within the ComplexUserSetting Class
    
    Attributes:
        name (str):         The name of the setting
        description (str):  A description of what the setting does
        value:              The current value of the setting
        default_value:      The default value of the setting
        setting_type (str): The type of the setting (e.g., 'int', 'bool', 'string')
        validation_func:    A function that validates the setting value
    """
    ###############################################################################
    # Dunder Mifflin Methods O_O
    ###############################################################################
    def __init__(self, name, value, description="", default_value=None, setting_type=None, validation_func=None):
        self.name:          str = name
        self.description:   str = description
        self.__value            = value
        self.default_value      = default_value if default_value is not None else value
        self.setting_type       = setting_type
        self.validation_func    = validation_func

    def __str__(self):
        return f"{self.name}: {self.value} ({self.description})"

    def __repr__(self):
        return f"UserSetting(name='{self.name}', value={self.value}, default_value={self.default_value})"
    ###############################################################################
    # Getter, Setter, and Reset Function
    ###############################################################################
    @property
    def value(self):
        """Get the current value of the setting."""
        return self.__value
    #______________________________________________________________________________
    def set_value(self, new_value):
        """Set the value of the setting with validation."""
        # Type validation if setting_type is specified
        if self.validation_func:
            new_value = self.validation_func(new_value)
        if self.setting_type:
            if self.setting_type == 'int' and not isinstance(new_value, int):
                try:
                    new_value = int(new_value)
                except (ValueError, TypeError):
                    raise ValueError(f"Setting '{self.name}' requires an integer value")
            elif self.setting_type == 'float' and not isinstance(new_value, float):
                try:
                    new_value = float(new_value)
                except (ValueError, TypeError):
                    raise ValueError(f"Setting '{self.name}' requires a float/decimal value")
            elif self.setting_type == 'bool' and not isinstance(new_value, bool):
                if isinstance(new_value, str):
                    if new_value.lower() in ['true', 't', 'yes', 'y', '1']:
                        new_value = True
                    elif new_value.lower() in ['false', 'f', 'no', 'n', '0']:
                        new_value = False
                    else:
                        raise ValueError(f"Setting '{self.name}' requires a boolean value")
                else:
                    try:
                        new_value = bool(new_value)
                    except (ValueError, TypeError):
                        raise ValueError(f"Setting '{self.name}' requires a boolean value")
        # All validation passed, set the new value
        self.__value = new_value
    #______________________________________________________________________________
    def reset(self):
        """Reset the setting to its default value."""
        if self.default_value != None:
            self.__value = self.default_value
    


class ComplexUserSetting:
    """
    A class representing a complex user setting that contains nested settings.
    
    This class provides dictionary-like access to a collection of settings,
    along with additional functionality for validation and management.
    """
    ###############################################################################
    # Dunder Mifflin Methods O_O
    ###############################################################################
    def __init__(self, name: str, description: str):
        self.name:              str                     = name
        self.description:       str                     = description
        self.nested_settings:   Dict[str, UserSetting]  = {}.copy()
        self.metadata:          Dict[str, set]          = {
            "expected_settings": set(),
            "required_settings": set()
        }
    #______________________________________________________________________________
    def __str__(self):
        return f"{self.name} ComplexUserSetting with {len(self.nested_settings)} settings"
    
    #______________________________________________________________________________
    def __repr__(self):
        return f"ComplexUserSetting(name='{self.name}', {len(self.nested_settings)} settings)"

    ###############################################################################
    # get_value functions
    ###############################################################################
    #______________________________________________________________________________
    def get_nested_settings(self):
        """Return all UserSetting names in the nested settings."""
        return self.nested_settings.keys()
    #______________________________________________________________________________
    def get_nested_values(self):
        """Return all values in the nested settings."""
        return self.nested_settings.values()
    
    #______________________________________________________________________________
    def get_nested_items(self):
        """
        Return all key-value pairs in the nested settings.\n
        setting.name, setting
        """
        return self.nested_settings.items()
    
    #______________________________________________________________________________
    def get_specific_setting(self, setting_name, default=None):
        """
        Get a nested setting, with a default if it doesn't exist.
        Example: setting.get('theme', 'light')
        """
        return self.nested_settings.get(setting_name, default)
    ###############################################################################
    # Verification functions
    ###############################################################################
    #______________________________________________________________________________
    def set_required_settings(self, setting_names):
        """
        Set which UserSettings are required for this complex setting.
        
        Args:
            setting_names (list or set): The UserSettings that are required
        """
        self.metadata["required_settings"] = set(setting_names)

    @property
    def required_settings(self) -> set[str]:
        '''
        returns: set of required settings by name
        '''
        return self.metadata["required_settings"]

    #______________________________________________________________________________
    def validate(self):
        """
        Validate that the complex setting contains all required keys.
        
        Returns:
            bool: True if valid, False otherwise
        """
        # Check that all required keys are present
        for key in self.metadata["required_settings"]:
            if key not in self.nested_settings:
                return False
        return True
    ###############################################################################
    # Manipulate Setting Values
    ###############################################################################
    #______________________________________________________________________________
    def reset_all(self):
        """
        Reset all nested settings to their default values.
        This only works for settings that are UserSetting instances.
        """
        for _, setting in self.nested_settings.items():
            setting.reset()
    #______________________________________________________________________________
    def add_setting(self, setting: UserSetting):
        """
        Add a new setting to the complex setting.
        Args:
            setting (UserSetting): The setting to add
        """
        self.nested_settings[setting.name] = setting
    
    #______________________________________________________________________________
    def remove_setting(self, setting_name: str):
        if setting_name in self.required_settings:
            print(f"{setting_name} is required and may not be removed")
            return f"{setting_name} is required and may not be removed"
        else:
            del self.nested_settings[setting_name]

    #______________________________________________________________________________
    def update_setting(self, setting_name: str, setting_value):
        setting = self.get_specific_setting(setting_name)
        setting.set_value(setting_value)

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
    ###############################################################################
    # Dunder Mifflin Methods O_O
    ###############################################################################
    def __init__(self, list_of_all_modules, list_of_all_subjects):
        # List of Complex Settings
        self.__activation_status_of_modules         = None
        self.__subject_interest_levels              = None
        self.__subject_priority_settings            = None
        self.__user_general_interest_settings       = None
        # List of Basic Settings
        self.__modules_default_activation_status    = None
        self._verify_build(list_of_all_modules, list_of_all_subjects)

    def _verify_build(self, list_of_all_modules, list_of_all_subjects):
        '''
        Check if each instance variable exists and of proper type\n
        If not of proper type or not existing, calls the appropriate build function to initialize it
        '''
        # Check Small Settings First
        if not isinstance(self.__modules_default_activation_status, UserSetting):
            self._build_initial_modules_default_activation_status_setting()

        # Check Complex Settings Second (Some complex settings might rely on simpler settings)
        if not isinstance(self.__activation_status_of_modules, ComplexUserSetting):
            self._build_initial_activation_status_of_modules_setting(list_of_all_modules)

    
        if not isinstance(self.__subject_interest_levels, ComplexUserSetting):
            self._build_initial_subject_interest_settings(list_of_all_subjects)
        
        if not isinstance(self.__subject_priority_settings, ComplexUserSetting):
            self._build_initial_subject_priority_settings(list_of_all_subjects)

        if not isinstance(self.__user_general_interest_settings, ComplexUserSetting):
            # self._build_initial_general_interest_settings()
            print(f"Are you going to implement the general interest settings?")
            pass #FIXME Yes fix it, you should add this, but not now. Will construct based on some new Interest Inventory testing.
    ###############################################################################
    # Validation Functions - Static Methods for custom validation of UserSettings
    ###############################################################################
    @staticmethod
    def _validation_for_subject_interest_level_setting(value):
        '''validation function as named, enforces range of 0 to 1000 for subject interest, to be passed into an individual subject_interest UserSetting'''
        if not isinstance(value, int):
            try:
                value = int(value)
            except (ValueError, TypeError):
                return 0
        return max(0, min(value, 1000))
    ###############################################################################
    # Initial Build Functions
    ###############################################################################
    def _build_initial_modules_default_activation_status_setting(self):
        self.__modules_default_activation_status = UserSetting(
            name            =   "modules_default_activation_status",
            value           =   True,
            description     =   "Defines whether the UserQuestionObject.is_active values within an added module are set to True or False, this property defines whether a new question will be placed into the 'reserve_bank' or 'deactivated' columns of the UserProfile revision schedule",
            default_value   = True,
            setting_type    = 'bool',
            validation_func = None # No custom validation necessary for default bool status
        )

    def _build_initial_activation_status_of_modules_setting(self, list_of_all_modules):
        # Need a full list of all modules in the QuizzerDB (which should be able to grab from the QuestionModuleDB)
        # Since this call lies further up the call chain, we'll need to pass it down when this is called
        self.__activation_status_of_modules = ComplexUserSetting(
            name        = "activation_status_of_modules",
            description = "Record of which modules are active or inactive in a user's UserProfile"
        )
        self.__activation_status_of_modules: ComplexUserSetting
        for module_name in list_of_all_modules:
            self.__activation_status_of_modules.add_setting(
                UserSetting(
                    name            =   module_name,
                    value           =   self.__modules_default_activation_status.value,
                    description     =   f"Is module with name: '{module_name}' currently active?",
                    default_value   =   self.__modules_default_activation_status.value,
                    setting_type    =   'bool',
                    validation_func =   None # No custom validation need for booleans
                )
            )
    
    def _build_initial_subject_interest_settings(self, list_of_all_subjects):
        # Need a full list of all settings (which should be able to grab from the QuestionObjectDB subject index that gets built)
        # Since this call lies further up the call chain, we'll need to pass it down when this is called
        self.__subject_interest_levels = ComplexUserSetting(
            name        = "subject_interest_levels",
            description = "Contains a numeric value that represents a User's Interest level in a given subject\nHigher values indicate more interest"
        )
        self.__subject_interest_levels: ComplexUserSetting
        for subject_name in list_of_all_subjects:
            self.__subject_interest_levels.add_setting(
                UserSetting(
                    name            =   subject_name,
                    value           =   10,
                    description     =   f"The amount of interest the user has in subject: {subject_name}",
                    default_value   =   10, # default interest level of 10, representing low interest level
                    setting_type    =   'int', # Could be of type of float, but should be easier to understand conceptually as an integer value
                    validation_func =   self._validation_for_subject_interest_level_setting
                )
            )
    
    def _build_initial_subject_priority_settings(self, list_of_all_subjects):
        self.__subject_priority_settings = ComplexUserSetting(
            name        = "subject_priority_settings",
            description = "Contains a numeric value to define the which subjects are being prioritized"
        )
        self.__subject_priority_settings: ComplexUserSetting
        for subject_name in list_of_all_subjects:
            self.__subject_priority_settings.add_setting(
                UserSetting(
                    name            = subject_name,
                    value           = 5,
                    description     = f"The user defined priority level for subject: {subject_name}",
                    default_value   = 5,
                    setting_type    = 'int',
                    validation_func = None # No custom validation, since not limiting to 1-10, allows priorities to be more flexible, user may manually set a hypothetical 1000 subjects with n+1 priority for ever subject if they so please
                )
            )

    def _build_initial_general_interest_settings(self):
        # This will be additional data, allowing the user to manually tell Quizzer what thier likes and dislikes are, potentially useless data, but you never know what might be relevant
        raise NotImplementedError("GUFFA!!!")
    ###############################################################################
    # Custom Construction Functionality for Complex Settings
    ###############################################################################

    ###############################################################################
    # Access Functionality for Settings
    ###############################################################################
    #______________________________________________________________________________
    # Get/Update for default activation status for modules
    def get_value_of_modules_default_activation_status(self):
        return self.__modules_default_activation_status
    
    def update_value_of_modules_default_activation_status(self, new_value: bool):
        self.__modules_default_activation_status: UserSetting
        self.__modules_default_activation_status.set_value(new_value = new_value)

    #______________________________________________________________________________
    # Get/Update for Subject Interest Settings
    def get_value_of_subject_interest_level(self, subject_name: str):
        return self.__subject_interest_levels.get_specific_setting(subject_name)
    
    def update_value_of_subject_interest_level(self, subject_name: str, new_value: int):
        self.__subject_interest_levels.update_setting(subject_name, new_value)

    #______________________________________________________________________________
    # Get/Update for Subject Priority Settings
    def get_value_of_subject_priority(self, subject_name:str):
        return self.__subject_priority_settings.get_specific_setting(subject_name)
    
    def update_value_of_subject_priority(self, subject_name:str, new_value: int):
        self.__subject_priority_settings.update_setting(subject_name, new_value)
    #______________________________________________________________________________
    # Get/Update for module_activation statusi
    def get_module_activation_status(self, module_name:str):
        return self.__activation_status_of_modules.get_specific_setting(module_name)
    
    def update_module_activation_status(self, module_name:str, new_value: bool):
        self.__activation_status_of_modules.update_setting(module_name, new_value)
    #______________________________________________________________________________
    # Get/Update for General Interest Settings
    #FIXME Once you add in this setting of course


class UserStat():
    '''Individual Stat Block representing some statistical measure'''
    # Yes, this is just a clone of the UserSetting Class, with setting renamed to stat
    ###############################################################################
    # Dunder Methods
    ###############################################################################
    def __init__(self, 
                 name, 
                 value, 
                 description:       str, 
                 default_value                  = None, 
                 stat_type                      = None, 
                 validation_func:   Callable    = None, 
                 date_of_entry:     date        = date.today()):
        
        self.name:          str = name
        self.description:   str = description
        self.__value            = value
        self.__date_of_entry    = date_of_entry
        self.stat_type          = stat_type
        self.validation_func    = validation_func

    def __str__(self):
        return f"{self.name}: {self.value} ({self.description})"

    def __repr__(self):
        return f"UserStat(name='{self.name}', value={self.value}, date_of_entry={self.date_of_entry}"
    ###############################################################################
    # Getter, Setter, and Reset Function
    ###############################################################################
    @property
    def value(self):
        '''Get the current value of the stat'''
        return self.__value
    
    @property
    def date_of_entry(self):
        '''Get the date of record for this stat block'''
        return self.__date_of_entry
    #______________________________________________________________________________
    def set_value(self, new_value):
        """Set the value of the stat with validation."""
        # Type validation if setting_type is specified
        if self.validation_func:
            new_value = self.validation_func(new_value)
        if self.stat_type:
            if self.stat_type == 'int' and not isinstance(new_value, int):
                try:
                    new_value = int(new_value)
                except (ValueError, TypeError):
                    raise ValueError(f"Stat '{self.name}' requires an integer value")
            elif self.stat_type == 'float' and not isinstance(new_value, float):
                try:
                    new_value = float(new_value)
                except (ValueError, TypeError):
                    raise ValueError(f"Stat '{self.name}' requires a float/decimal value")
            elif self.stat_type == 'bool' and not isinstance(new_value, bool):
                if isinstance(new_value, str):
                    if new_value.lower() in ['true', 't', 'yes', 'y', '1']:
                        new_value = True
                    elif new_value.lower() in ['false', 'f', 'no', 'n', '0']:
                        new_value = False
                    else:
                        raise ValueError(f"Stat '{self.name}' requires a boolean value")
                else:
                    try:
                        new_value = bool(new_value)
                    except (ValueError, TypeError):
                        raise ValueError(f"Stat '{self.name}' requires a boolean value")
        # All validation passed, set the new value
        self.__value = new_value



class HistoricalUserStat():
    '''Is a historical record of Stats\n
    For example: if we track how many questions a user answered today, it will go here under a key with name {date} and value that corresponds with that day\n

    The values of the HistoricalUserStat are UserStat objects:\n
    name: Title for Stat Block\n
    description: description of what hte Stat Block indicates\n
    default_value_type: If values are missing what should they default to? -> options are ('zero', 'previous', float, int, bool)
    '''
    def __init__(self, name:            str,
                 description:           str,
                 default_value_type,
                 ):
        self.name:                  str = name
        self.description:           str = description
        self.default_value_type         = default_value_type
        self.nested_stats:          Dict[date, UserStat] = {}.copy() 
        self.metadata:              Dict[str, set]       = {
            'expected_stats': set(),
            'required_stats': set() # exists but not going to be used yet
        }
    #______________________________________________________________________________
    def __str__(self):
        return f"{self.name} HistoricalUserStat with {len(self.nested_stats)} dated stats"
    #______________________________________________________________________________
    def __repr__(self):
        return f"HistoricalUserStat(name='{self.name}', {len(self.nested_stats)} dated stats)"
    ###############################################################################
    # get_value functions
    ###############################################################################
    @property
    def value_most_recent(self):
        self._fill_missing_dates()
        try:
            most_recent_date = max(self.nested_stats.keys())
            return self.nested_stats[most_recent_date].value
        except:
            return None
    #______________________________________________________________________________
    @property
    def max_value(self):
        self._fill_missing_dates()
        if not self.nested_stats:
            return None
        return max(stat.value for stat in self.nested_stats.values())

    @property
    def min_value(self):
        self._fill_missing_dates()
        if not self.nested_stats:
            return None
        return min(stat.value for stat in self.nested_stats.values())
    #______________________________________________________________________________
    @property
    def average_value(self):
        self._fill_missing_dates()
        if not self.nested_stats:
            return None
        return sum([stat.value for stat in self.get_nested_values()])/len(self.nested_stats)
    #______________________________________________________________________________
    @property
    def trend(self):
        '''Return trend line indicator'''
        self._fill_missing_dates()
        # FIXME should be updated with more accurate/complex business logic
        if len(self.nested_stats) < 2:
            return None
        sorted_data = sorted([(d, stat.value) for d, stat in self.nested_stats.items()])
        midpoint = len(sorted_data) // 2
        early_values    = [val for _, val in sorted_data[:midpoint]]
        recent_values   = [val for _, val in sorted_data[midpoint:]]
        early_avg       = sum(early_values) / len(early_values)
        recent_avg      = sum(recent_values) / len(recent_values)
        return recent_avg - early_avg
    #______________________________________________________________________________
    def get_stats_by_date_range(self,
                                start_date: date,
                                end_date:   date) -> Dict[date, UserStat]:
        '''
        Returns all stats that fall within the specified date range (inclusive)\n
        Parameters:
        start_date: Beginning of date range
        end_date:   End of date range

        Returns:
            Dictionary of {date: UserStat} entries within the range
        '''
        return {date_obj: user_stat for date_obj, user_stat in self.nested_stats.items() if start_date <= date_obj <= end_date}



    #______________________________________________________________________________
    def get_nested_stat_dates(self):
        '''returns all the dates with recorded stats'''
        return self.nested_stats.keys()
    #______________________________________________________________________________
    def get_nested_values(self):
        '''returns just the values in the historical record'''
        return self.nested_stats.values()
    #______________________________________________________________________________
    def get_nested_items(self):
        '''returns all date: value pairs in this stat_block'''
        return self.nested_stats.items()
    #______________________________________________________________________________
    def get_specific_stat(self, date, default=None):
        '''Get the value of the stat block for a certain day'''
        return self.nested_stats.get(date, default)
    ###############################################################################
    # Manipulate Setting Values
    ###############################################################################
    def add_stat_record(self, stat: UserStat):
        '''
        Add or Overwrite Stat record for this HistoricalStat
        If the passed stat already exists for that date, it will overwrite the value, else it will add the stat into the record by the date of the passed stat.
        '''
        if self.nested_stats.get(stat.date_of_entry) == None:
            self.nested_stats[stat.date_of_entry] = stat
        else:
            self.nested_stats[stat.date_of_entry].set_value(stat.value)
    ###############################################################################
    # Validation Functionality
    ###############################################################################
    def _get_dates_with_missing_values(self) -> list:
        '''returns a list of dates that missing in the record'''
        if len(self.nested_stats) < 2:
            return []
        self.nested_stats   = helper.sort_dictionary_keys(self.nested_stats)
        dates = list(self.get_nested_stat_dates())
        start_date = dates[0]
        end_date   = dates[-1]

        all_dates = [start_date + timedelta(days=i) for i in range((end_date-start_date).days+1)]

        return [date_obj for date_obj in all_dates if date_obj not in self.nested_stats]
    #______________________________________________________________________________
    def _fill_missing_dates(self):
        '''Fills missing dates with default value as defined by instance.default_value_type'''
        missing_dates = self._get_dates_with_missing_values()
        if not missing_dates or not self.nested_stats:
            return None
        sample_stat = next(iter(self.nested_stats.values()))
        for missing_date in missing_dates:
            if self.default_value_type == 'zero':
                new_value = 0
            elif self.default_value_type == 'previous':
                prev_dates = [date_obj for date_obj in self.nested_stats.keys() if date_obj < missing_date]
                if prev_dates:
                    prev_date = max(prev_dates)
                    new_value = self.nested_stats[prev_date].value
                else:
                    new_value = 0 # If no previous stat default to 0
            else:
                new_value = self.default_value_type
            self.add_stat_record(
                UserStat(
                    name            = sample_stat.name,
                    value           = new_value,
                    description     = sample_stat.description,
                    stat_type       = sample_stat.stat_type,
                    validation_func = sample_stat.validation_func,
                    date_of_entry   = missing_date
                )
            )
        self.nested_stats   = helper.sort_dictionary_keys(self.nested_stats)
        

    # Will not be adding a remove_stat, all stats are permanent record, so I will not be including any method to remove them

    

class UserProfileStatsDB:
    '''
    Subclass to store all User statistics\n
    Stats to Included (FIXME if not implemented)\n
    All stats are historical records over time: properties are made to get just todays stat\n

    total_in_circulation_questions_history:             \n
    "current_eligible_questions":                       \n
    "reserve_questions_exhaust_in_x_days":              \n
    "non_circulating_questions":                        \n
    "Graphical Charts":                                 FIXME\n
    "revision_streak_stats":                            \n
    "total_questions_in_database"(historical):          \n
    "total_questions_answered":                         \n
        This one can be verified by the attempt history
    "questions_answered_by_date":                       \n
    '''
    # Notes:
    # "average_per_day" figure is now a property of questions_answered_by_date
    # "current_num_questions_in_circulation" figure is now a property of total_questions_in_circulation
    ###############################################################################
    # Dunder Mifflin Methods O_O
    ###############################################################################
    def __init__(self, UserQuestionsDB_REF, UserSettingsDB_REF):
        self.__UserQuestionsDB_REF: UserProfileQuestionDB   =   UserQuestionsDB_REF
        self.__UserSettingsDB_REF:  UserProfileSettingsDB   =   UserSettingsDB_REF
        self.questions_answered_by_date = None
        self.total_questions_answered   = None

        self._build_initial_stats_frame()
    #______________________________________________________________________________
    def _build_initial_stats_frame(self):
        # Adding fix me's to every stat needs an actuall get/set method
        self.questions_answered             = HistoricalUserStat(
            name                = "Questions Answered By Date",
            description         = "Full record of how many questions the user has answered every day",
            default_value_type  = 'zero'
        )

        self.total_questions_answered       = HistoricalUserStat(
            name                = "Total Questions Answered",
            description         = "Running total of questions answered",
            default_value_type  = 'previous'
        )

        self.total_questions_in_profile     = HistoricalUserStat(
            name                = "Total UserQuestionObjects",
            description         = "Running total of how many UserQuestionObjects are in the user's UserProfileQuestionDB",
            default_value_type  = 'previous'
        )
        
        self.total_in_circulation_questions = HistoricalUserStat(
            name                = "Total Circulating Questions",
            description         = "Running total of how many questions are currently circulating for the user, sum of questions not in reserve_bank or deactivated on the review schedule",
            default_value_type  = 'previous'
        )
        self.total_non_circulating_questions = HistoricalUserStat(
            name                = "Total Out of Circulation Questions",
            description         = "Running total of how many questions are not in circulation, (either in reserve_bank or deactivated columns of review schedule)",
            default_value_type  = 'previous'
        )
        self.revision_streak_stats      = UserStat(
            name                = "Revision Streak Stats",
            description         = "record of how many questions exist for any given revision score, '1: 10, 2: 50, 3: 49'",
            date_of_entry       = date.today()
        )
        self.avg_daily_questions_shown  = UserStat(
            name                = "Average Daily Questions Shown to User",
            description         = "Represents the amount of questions that the User needs to answer daily in order to maintain retention of their knowledge base",
            date_of_entry       = date.today()
        )
    #______________________________________________________________________________
    @property
    def current_eligible_questions(self):
        '''The current amount of questions eligible for review'''
        review_schedule = self.__UserQuestionsDB_REF.get_review_schedule()
        # Iterate over schedule to get columns that are within today's date
        today = date.today()
        eligible_questions = []
        for date_obj, question_ids in review_schedule.items():
            question_ids: list[str]
            if date_obj == "reserve_bank" or date_obj == "deactivated":
                pass
            elif date(date_obj) <= today:
                eligible_questions.extend(
                    [i for i in question_ids if self.__UserQuestionsDB_REF.get_specific_UserQuestionObject(i).is_eligible]
                )
        return len(eligible_questions)
    #______________________________________________________________________________
    @property
    def average_daily_increase_in_total_circulating_questions(self):
        # Ensure all dates are filled with appropriate values
        self.total_in_circulation_questions._fill_missing_dates()
        stats = self.total_in_circulation_questions.nested_stats.copy()
        if len(stats) < 2:
            return 0 # Need at least two data points
        dates = list(stats.keys())
        
        first_date = dates[0]
        last_date  = dates[-1]

        days_span = (last_date-first_date).days
        if days_span == 0:
            return 0 # Same day, can't calculate rate
        total_change= stats[last_date].value - stats[first_date].value
        return total_change / days_span

    @property
    def number_of_days_until_reserve_questions_are_exhausted(self):
        '''Based on the current average, how many days until you learn all available material'''
        if self.average_daily_increase_in_total_circulating_questions <= 0:
            return 9999999
        return self.total_non_circulating_questions.value_most_recent / self.average_daily_increase_in_total_circulating_questions
    

        # Will be a series of calls to the Calculate Stats Function
    ###############################################################################
    # Individual Update Stat Calls
    ###############################################################################
    #______________________________________________________________________________
    def _update_questions_answered(self):
        questions_answered = self.questions_answered.value_most_recent
        if questions_answered == None:
            questions_answered = 1
        else:
            questions_answered += 1
        self.questions_answered.add_stat_record(
            UserStat(
                name    = f"Questions Answered Today {date.today()}",
                description = "",
                value       = questions_answered
            )
        )
    def _update_total_questions_answered(self):
        # Since this is a running total, we need to find the max value, if no max value exists we'll get none
        total_questions_answered = self.total_questions_answered.max_value
        if total_questions_answered == None:
            total_questions_answered = 1
        else:
            total_questions_answered += 1
        self.total_questions_answered.add_stat_record(
            UserStat(
                name            = "Total Questions Answered",
                description     = f"Running Total amount of Questions Answered, all questions all dates",
                value           = total_questions_answered,
                date_of_entry   = date.today()
            )
        )
    def _update_total_questions_in_profile(self):
        self.total_questions_in_profile.add_stat_record(
            UserStat(
                name        = "Total Questions In Profile",
                description =   "Total Questions in all columns, by date",
                value       = self.__UserQuestionsDB_REF.total_questions_in_profile
            )
        )

    def _update_total_in_circulation_questions(self):
        total = 0
        for column_name, question_id_list in self.__UserQuestionsDB_REF.get_review_schedule().items():
            if column_name != "deactivated" and column_name != "reserve_bank":
                total += len(question_id_list)
        self.total_in_circulation_questions.add_stat_record(
            UserStat(
                name        = "Total Circulating Questions",
                description = "The total amount of questions circulating, represents the amount of questions the user has committed to memory",
                value       = total
            )
        )
    def _update_total_non_circulating_questions(self):
        review_schedule = self.__UserQuestionsDB_REF.get_review_schedule()
        total = len(review_schedule["reserve_bank"]) + len(review_schedule["deactivated"])
        self.total_non_circulating_questions.add_stat_record(
            UserStat(
                name        = "Total Non Circulating Questions",
                description = "The amount of questions in the reserve_bank and deactivated columns of the review schedule",
                value       = total
            )
        )
    def _update_iterable_derived_stats(self):
        '''
        Some Stats require us to iterate over all the UserQuestionObjects and sum up individual values,
        Because of this, we will ignore the separation of concerns principle, and wrap all of these updates within a single loop instead of n-loops
        '''
        review_schedule = self.__UserQuestionsDB_REF.get_review_schedule()
        revision_data = {}.copy()
        avg_daily_questions_shown = 0
        for column_name, question_id_list in review_schedule.items():
            if column_name != "deactivated" and column_name != "reserve_bank":
                for question_id in question_id_list:
                    user_question = self.__UserQuestionsDB_REF.get_specific_UserQuestionObject(question_id)
                    # Handle Revision Streak Stat Block
                    if revision_data.get(str(user_question.revision_score)) == None:
                        revision_data[str(user_question.revision_score)] = 1
                    else:
                        revision_data[str(user_question.revision_score)] += 1
                    # Handle avg_daily_questions_shown stat (summation of avg_shown properties)
                    avg_daily_questions_shown += user_question.average_shown
        self.revision_streak_stats.set_value(revision_data)
        self.avg_daily_questions_shown.set_value(avg_daily_questions_shown)



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
    ###############################################################################
    # Dun Dun DunderS!
    ###############################################################################
    def __init__(self,
                 list_of_all_modules: list[str],
                 list_of_all_subjects: list[str],
                 username:          str,
                 email_address:     str,
                 full_name:         str,
                 tutorial_questions:str,
                 user_stats     =   None
                 ):
        self.user_uuid                              = self.generate_uuid()
        self.user_questions: UserProfileQuestionDB  = UserProfileQuestionDB(tutorial_questions)
        self.user_settings: UserProfileSettingsDB   = UserProfileSettingsDB(
            list_of_all_modules     = list_of_all_modules,
            list_of_all_subjects    = list_of_all_subjects
        )
        self.user_stats: UserProfileStatsDB         = user_stats
        self.username                               = username
        self.email_address: str                     = email_address
        self.full_name                              = full_name
        self._build_user_stats_db()
    #______________________________________________________________________________
    def __str__(self):
        full_print = ""
        for key, value in self.__dict__.items():
            full_print += f"{key:25}: {value}\n"
        return full_print
    
    ###############################################################################
    # Verification and build functionality:
    ###############################################################################
    def _build_user_stats_db(self):
        self.user_stats =   UserProfileStatsDB(self.user_questions, self.user_settings)
    ###################################
    # Core Functions (API)
    ###################################
    #______________________________________________________________________________
    def generate_uuid(self):
        '''
        Every user will have a Unique Universal ID (UUID) assigned upon profile creation
        '''
        return str(uuid.uuid4())
    #______________________________________________________________________________
    def add_question_to_UserProfile(self, question_id: str):
        self.user_questions.add_question(question_id) # This is purely an abstraction for easier calling from main program
        # self.add_question_to_UserProfile as opposed to self.user_questions.add_question, call is shorter as a result


    #______________________________________________________________________________
    def add_question_attempt(self,
                             module_name:   str, 
                             question_id:   str,
                             status:        str,
                             answer_speed:  float
                             ):
        user_question = self.user_questions.get_specific_UserQuestionObject(question_id)
        # Add the attempt with values at time of answer:
        user_question.add_attempt(
            status                          = status,

            answer_speed                    = answer_speed,

            module_name                     = module_name,

            questions_answered              = self.user_stats.questions_answered.value_most_recent,

            total_questions_answerd         = self.user_stats.total_questions_answered.max_value,

            current_eligible_questions      = self.user_stats.current_eligible_questions,

            total_questions_in_profile      = self.user_questions.total_questions_in_profile,

            total_in_circulation_questions  = self.user_stats.total_in_circulation_questions.value_most_recent,

            total_non_circulating_questions = self.user_stats.total_non_circulating_questions.value_most_recent,

            avg_daily_increase              = self.user_stats.average_daily_increase_in_total_circulating_questions,

            number_of_days_until_reserve_questions_are_exhausted    = self.user_stats.number_of_days_until_reserve_questions_are_exhausted
        )

        # After we add the attempt object, Statistics should be updated:
        self.user_stats._update_questions_answered()
        self.user_stats._update_total_questions_answered()
        self.user_stats._update_total_questions_in_profile()
        self.user_stats._update_total_in_circulation_questions()
        self.user_stats._update_total_non_circulating_questions()
        self.user_stats._update_iterable_derived_stats()