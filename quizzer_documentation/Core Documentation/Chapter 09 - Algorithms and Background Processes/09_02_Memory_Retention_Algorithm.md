# Memory Retention Algorithm
After a user answers a question and submits a response, how long should it be until it should be presented again in order to maximize memory retention?

The current formula is described in the old code base as follows:
```python
def calculate_next_revision_date(status: str, question_object:dict): #Private Function
    '''
    The core of Quizzer, predicated when the user will forget the information contained in the questions helps us accelerate learning to the max extent possible
    Runs the algorithm necessary for predicting when the User will forget the information and projects a date on which the user should revise next.
    '''
    # Function is isolated because algorithm for determining the next due date
    # is very much in need of an update to a more advanced determination system.
    # Needs to consider factors like what other questions and concepts the user knows and are related to question at hand
    
    ################################################################################################################3
    if question_object["time_between_revisions"] >= 1:
        question_object["time_between_revisions"] = 1
    elif question_object["time_between_revisions"] <= 0:
        question_object["time_between_revisions"] = 0.05
        # value has to be above 0, otherwise the function inverts
    # run the calculation
    x = question_object["revision_streak"] # number of repititions
    h = 4.5368 # horizontal shift
    k = question_object["time_between_revisions"] # constant, initial value of 0.37
    t = 36500 #days Maximum length of human memory (approximately one human lifespan)
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
    # Set this variable regardless
    question_object["average_times_shown_per_day"] = average_shown

    # Based on the status, decide whether to use the calculation or not
    if status == "correct":
        question_object["next_revision_due"] = datetime.now() + timedelta(days=number_of_days)
        print(f"To be reviewed in {number_of_days:.2f} days or {(number_of_days*24):.2f} hours")
    else: # if not correct then incorrect, function should error out if status is not fed into properly:
        # Intent is to make an incorrect question due immediately and of top priority
        question_object["next_revision_due"] = datetime.now()    
    return question_object
```