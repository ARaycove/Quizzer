import random
import math
import pickle
import time
import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from QuestionObject import QuestionObject
from datetime       import datetime, date, timedelta
from lib import helper
import numpy        as np
import pandas       as pd


class Attempt:
    '''
    All values of the attempt record are the values at the time of the attempt, not the values after the update is made
    '''
    def __init__(self,
                 date_of_attempt:   datetime,
                 status:            str,
                 answer_speed:      datetime,
                 revision_score:    int,
                 total_attempts:    int,
                 last_revised:      datetime,
                 next_revision_due: datetime
                 ):
        self.date_of_attempt    = date_of_attempt
        self.status             = status
        self.answer_speed       = answer_speed
        self.revision_score     = revision_score
        self.total_attempts     = total_attempts
        self.last_revised       = last_revised
        self.next_revision_due  = next_revision_due

    def __str__(self):
        return f"{self.__dict__}"
    
    def return_pandas_table(self):
        return pd.DataFrame([self.__dict__])

class UserQuestionObject:
    '''
    Tracks the User's relationship and usage data with respective to a single QuestionObject within Quizzer's database
    Properties of UserQuestionObject
    revision_score:     active score, representing how well the user is acquainted with this question
    last_revised:       The date in which the user last revised this question
    next_revision_due:  The exact date and time the user should revise this question in order to ensure retention of the given material
    attempt_history:    list object of all attempts the user has made with this question
    h:                  marks the horizontal shift of the memory equation

    Embedded Attempt object
        date_of_attempt The exact time in which the attempt was added
        status:         Answered question -> (correct, incorrect, or repeat)
        answer_speed    How long in seconds the user took to answer that question

    time_between_revisions: The constant variable in the memory equation
    in_circulation:     Whether or not the question is being actively shown to the user
    is_eligible:        derived property, checks whether this question is eligible for review at this point in time
    total_attempts:     derived property, the number of times the user has provided an attempt at an answer to this question
    
    Old module system is being scrapped as of right now
    '''
    #############
    # Dunder Methods
    t = 36500
    def __init__(self, 
                 question:                  QuestionObject,
                 last_revised:              datetime        = datetime.now(),
                 next_revison_due:          datetime        = datetime.now(),
                 attempt_history:           list[Attempt]   = None,
                 ):
        self.question: QuestionObject   = question
        self.last_revised               = last_revised
        self.next_revison_due           = next_revison_due
        self.attempt_history            = attempt_history
        self.__time_between_revisions   = 0.38 # k constant in memory equation
        self.__h                        = 4.5368
        self.__in_circulation           = False
        self.__revision_score           = 1
        self.__total_attempts           = 0
        self.__correct_attempts         = 0
        self.__wrong_attempts           = 0
        self._build_object()
    def __str__(self):
        full_print = ""
        for key, value in self.__dict__.items():
            if value == self.question:
                for key, value in self.question.__dict__.items():
                    full_print += f"{f"question.{key}":25.25}: {value}\n"
            else:
                full_print += f"{key:25}: {value}\n"
        return full_print
    def __eq__(self, other):
        if not isinstance(other, UserQuestionObject):
            return False
        # Compare the internal question objects using their equality method
        return self.question == other.question
    #############
    # Initialization Code
    def _build_object(self):
        if self.attempt_history == None:
            self.attempt_history = [].copy() # copy of empty list, just for redundancy sake
        self._calculate_next_revision_date()
    #############
    # property (derivative stats)
    @property
    def total_attempts(self):
        return self.__total_attempts

    @property
    def correct_attempts(self):
        return self.__correct_attempts

    @property
    def wrong_attempts(self):
        return self.__wrong_attempts

    @property
    def revision_score(self):
        return self.__revision_score
    
    @property
    def is_eligible(self):
        '''
        Default sensitivity set to 1 hours, removing from user_settings
        '''
        is_eligible = False
        if self.next_revison_due <= (datetime.now()-timedelta(hours=1)):
            is_eligible = True
        return is_eligible
    
    @property
    def in_circulation(self):
        return self.__in_circulation
    
    @in_circulation.setter
    def in_circulation(self, value):
        print("You tried to change the in_circulation property directly, please use the place into or remove from functions for that")
    
    #############
    # Add new attempt data to object:
    def _calculate_next_revision_date(self):
        '''
        Whenever the next_revision is calculated we also update the average_shown, average_shown is an embedded property
        '''
        x = self.__revision_score # number of repititionsmath.pow(
        h = self.__h # horizontal shift
        k = self.__time_between_revisions # constant, initial value of 0.37
        t = 36500 # days Maximum length of human memory (approximately one human lifespan), yes there is the potential for someone to live to 100, but let's just say 100 years is the max lifespan for a human being
        numerator   = math.pow(math.e, (k*(x-h)))
        denominator = 1 + (numerator/t)
        fraction = numerator/denominator
        def calc_g(h, k, t):
            num = math.pow(math.e, (k*(0-h)))
            denom = 1 + (numerator/t)
            fraction = num/denom
            return -fraction
        g = calc_g(h, k, t)
        number_of_days = fraction+g
        average_shown = 1 / number_of_days
        self.average_shown      = average_shown
        self.next_revison_due   = datetime.now() + timedelta(days=number_of_days)

    def _update_user_question_object(self, status):
        # Update the revision score based on the given answer
        if status == "correct":
            if helper.within_twenty_four_hours(self.next_revison_due) == False:
                self.__time_between_revisions += 0.005 # If correct and answered way past the due_date, alter the constant for a steeper curve
            self.__revision_score   += 1
            self.__correct_attempts += 1

        elif status == "incorrect":
            # reduce the k constant if the prediction was wrong, results in a more shallow curve
            if helper.within_twenty_four_hours(self.next_revison_due) == True:
                k_reduction = 0
                if self.__revision_score >= 6:
                    k_reduction = 0.015
                self.__time_between_revisions -= k_reduction
            self.__revision_score -= 1
            self.__wrong_attempts += 1
            # Enforce minimum revision score of 1
            if self.__revision_score <= 0:
                self.__revision_score = 1

        # Now update revision metrics, due date and last revision
        self.__total_attempts += 1
        self.last_revised = datetime.now()
        self._calculate_next_revision_date()

    def add_attempt(self, status, answer_speed: float):
        '''
        Records the current state of the object, each attempt is a record of the user's history with the question at that point in time
        The second function of adding an attempt record is the need to update the state of the object -> replaces the old update_score function
        '''
        # First we will update the status of the object with current revision
        # Validation metric, ensuring status of correct type
        answer_speed = float(answer_speed)
        valid_statusi = ["correct", "incorrect", "repeat"]
        if status not in valid_statusi:
            raise Exception("status must be 'correct', 'incorrect', or 'repeat'")

        # Record the current state of the UserQuestionObject
        self.attempt_history.append(Attempt(
            date_of_attempt =   datetime.now(),
            status =            status,
            answer_speed =      answer_speed,
            revision_score =    self.revision_score,
            total_attempts =    self.total_attempts,
            last_revised =      self.last_revised,
            next_revision_due=  self.next_revison_due
        ))

        # Update other metrics as necessary
        self._update_user_question_object(status)

    def place_into_circulation(self):
        '''
        Add the question into user's active Quizzer
        '''
        self.__in_circulation = True

    def remove_from_circulation(self):
        '''
        Remove the question from the user's active Quizzer
        '''
        self.__in_circulation = False



if __name__ == "__main__":
    start_test = datetime.now()
    trial_object = {
                "revision_streak": 9,
                "last_revised": "2025-03-14 21:07:22", # 
                "next_revision_due": "2025-03-20 03:40:33", # private function that calculates this upon add_attempt
                "in_circulation": True, # initialized as false
                "time_between_revisions": 0.38, # initialized as a constant
                "average_times_shown_per_day": 0.18964389787059233, # now derived as a consequence of calculated the next revision due, will only change based on the revision score
                "is_eligible": False,
                "is_module_active": False,
                "answer_times": [ # Abstracted into attempt object
                    "3.575833",
                    "2.20416",
                    "3.984533",
                    "3.262558",
                    "5.55888",
                    "3.916518",
                    "2.596285",
                    "1.76984",
                    "2.298966",
                    "3.321259",
                    "1.973846",
                    "2.338196",
                    "2.412269",
                    "2.055687"
                ],
                # Attempts abstracted into attempt object
                "correct_attempt_history": {
                    "2025-02-27": 1,
                    "2025-02-28": 2,
                    "2025-03-04": 1,
                    "2025-03-05": 1,
                    "2025-03-07": 1,
                    "2025-03-09": 1,
                    "2025-03-14": 1
                },
                "incorrect_attempt_history": {
                    "2025-02-27": 1,
                    "2025-02-28": 0,
                    "2025-03-04": 0,
                    "2025-03-05": 0,
                    "2025-03-07": 0,
                    "2025-03-09": 0,
                    "2025-03-14": 0
                },
                "revision_streak_history": {
                    "2025-02-27": 2,
                    "2025-02-28": 4,
                    "2025-03-04": 5,
                    "2025-03-05": 6,
                    "2025-03-07": 7,
                    "2025-03-09": 8,
                    "2025-03-14": 9
                },
                "total_answers": 1 # Should be a property len(attempt_history)
            }
    print("Running Unit Tests for UserQuestionObject")
    base_question_object = None
    with open("TestQuestionObject.pickle", "rb") as f:
        base_question_object: QuestionObject = pickle.load(f)
        print(f"    Type of loaded object: {type(base_question_object)}")
        print(f"    Successfully Loaded QuestionObject class: {isinstance(base_question_object, QuestionObject)}")
    print(f"    Attempting to initialize new instance of object UserQuestionObject")
    test_user_question_object = UserQuestionObject(
        question = base_question_object
    )
    print(f"    Success")
    print(f"    Printing Object")
    print(test_user_question_object)
    with open("TestUserQuestionObject.pickle", "wb") as f:
        pickle.dump(test_user_question_object, f, protocol=pickle.HIGHEST_PROTOCOL)
        print(f"    Test Save Successful")

    with open("TestUserQuestionObject.pickle", "rb") as f:
        loaded_object = pickle.load(f)
        print(f"    Test Load Successful")
    print(f"    Equivalency Test Succeeded: {test_user_question_object == loaded_object}")
    
    print(f"Class Variables Test")
    print(f"    t constant is: {test_user_question_object.t}")
    print(f"Property Tests")
    print(f"    Number of revisions: {test_user_question_object.total_attempts}")
    print(f"    Revision Score     : {test_user_question_object.revision_score}")
    print(f"    Eligibility        : {test_user_question_object.is_eligible}")
    print(f"    Getter for in_circ : {test_user_question_object.in_circulation}")
    test_user_question_object.in_circulation = "FAKE"
    print(f"    Safeguard for in_circulation get/set works: {test_user_question_object.in_circulation != "FAKE"}")
    print(f"    Correct/Wrong Attempts: {test_user_question_object.correct_attempts}/{test_user_question_object.wrong_attempts}")


    print(f"Repeating Load/Save Test:")
    with open("TestUserQuestionObject.pickle", "wb") as f:
        pickle.dump(test_user_question_object, f, protocol=pickle.HIGHEST_PROTOCOL)
        print(f"    Test Save Successful")

    with open("TestUserQuestionObject.pickle", "rb") as f:
        loaded_object = pickle.load(f)
        print(f"    Test Load Successful")
    print(f"    Equivalency Test Succeeded: {test_user_question_object == loaded_object}")


    print(f"Now testing funcitonality of Add Attempt")
    print(f"Generating fake attempts")
    for i in range(15):
        random_status = random.randint(0, 2)
        print(random_status, end="")
        valid_statusi = ["correct", "incorrect", "repeat"]
        test_user_question_object.add_attempt(valid_statusi[random_status], "15")
    print()

    print(f"Retesting properties with new revisions added")
    print(f"    Number of revisions: {test_user_question_object.total_attempts}")
    print(f"    correct/wrong      : {test_user_question_object.correct_attempts}/{test_user_question_object.wrong_attempts}")
    print(f"    Revision Score     : {test_user_question_object.revision_score}")

    print(f"Testing whether add and remove from circulation is working:")
    print(f"Status Should be False: {test_user_question_object.in_circulation}")
    test_user_question_object.place_into_circulation()
    print(f"Status Should be True: {test_user_question_object.in_circulation}")
    test_user_question_object.remove_from_circulation()
    print(f"Status Should be False: {test_user_question_object.in_circulation}")

    print(f"Testing next_revision_due calculation, should only update on added_attempt, not on access")
    print(f"Access results in:        {test_user_question_object.next_revison_due}")
    time.sleep(1) 
    print(f"Second access results in: {test_user_question_object.next_revison_due}")
    print(f"Adding correct attempt:")
    test_user_question_object.add_attempt("correct", 10)
    print(f"Access results in:        {test_user_question_object.next_revison_due}")

    print(f"Now testing pandas collection functionality")
    data_frame = pd.DataFrame()
    for attempt_record in test_user_question_object.attempt_history:
        data_frame = pd.concat([data_frame, attempt_record.return_pandas_table()])
    print(data_frame)
    
    end_test = datetime.now()
    print(f"Unit Tests took: {end_test-start_test} time")