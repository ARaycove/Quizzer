from datetime import date, datetime, timedelta
from lib import helper
def determine_total_eligible_questions(user_profile_data: dict):
    '''
    returns stats_data
    calculates based on the index, the total number of eligible questions
    '''
    # print("def determine_total_eligible_questions(user_profile_data: dict)")
    total_eligible_questions = len(user_profile_data["questions"]["in_circulation_is_eligible"])
    user_profile_data["stats"]["current_eligible_questions"] = total_eligible_questions
    # print(f"    Total eligible questions is {user_profile_data['stats']['current_eligible_questions']}")
    return user_profile_data

def initialize_and_update_questions_exhausted_in_x_days_stat(user_profile_data: dict) -> dict:
    # print("def initialize_and_update_questions_exhausted_in_x_days_stat(user_profile_data: dict) -> dict")            
    questions_not_in_circulation = len(user_profile_data["questions"]["reserve_bank"])
    user_profile_data["stats"]["non_circulating_questions"] = questions_not_in_circulation
    # The number of questions that are not in circulation divided by the average amount of questions that get put into circulation gives us the amount of days until there are no more questions left to add based on user performance
    # Figure can also be used to determine when the user will learn all of the material currently in their database
    if user_profile_data["stats"]["average_num_questions_entering_circulation_daily"] != 0:
        user_profile_data["stats"]["reserve_questions_exhaust_in_x_days"] = questions_not_in_circulation / user_profile_data["stats"]["average_num_questions_entering_circulation_daily"]
    else:
        user_profile_data["stats"]["reserve_questions_exhaust_in_x_days"] = 0
    # print(f"Number left to add is {questions_not_in_circulation}")
    # print(f"Average amount being added is {stats_data['average_num_questions_entering_circulation_daily']}")
    # print(f"User will get through all material in {stats_data['reserve_questions_exhaust_in_x_days']} days")
    # print(f"    Return Values are:")
    # print(f"    Non Circulating Questions: {user_profile_data['stats']['non_circulating_questions']}")
    # print(f"    Questions exhaust in < {user_profile_data['stats']['reserve_questions_exhaust_in_x_days']} > days")
    return user_profile_data

def calculate_average_num_questions_entering_circulation(user_profile_data: dict) -> dict:
    '''
    Stat represents how many questions in total over the span of num_days are getting their in_circulation value set to True
    That is, how many new questions per day on average is the user being shown?
    Stat helps to determine user pacing and how quickly they are learning new things
    '''
    # print("def calculate_average_num_questions_entering_circulation(user_profile_data: dict) -> dict")
    # It is my hope that development of a more advanced algorithm can increase this pace, but for now we can track speed of learning:
    stats_data = user_profile_data["stats"]
    begin_date = datetime.now() - timedelta(days=90)
    dates_in_past_ninety_days = []
    count = 0
    last_date = None
    for date, num in stats_data["total_in_circulation_questions"].items():
        temp_date = datetime.strptime(date, "%Y-%m-%d")
        if temp_date >= begin_date:
            dates_in_past_ninety_days.append(temp_date)
            if last_date != None:
                difference = num - last_value
                count += difference
                # Logic Here
        last_date = temp_date
        last_value = num
    oldest_date = min(dates_in_past_ninety_days)
    youngest_date = max(dates_in_past_ninety_days)
    total_days = (youngest_date - oldest_date).days
    if total_days != 0:
        average_num_daily = count / total_days
    else:
        # Don't divide by zero!
        average_num_daily = 0
    stats_data["average_num_questions_entering_circulation_daily"] = average_num_daily

    user_profile_data["stats"] = stats_data
    # print(f"    Return value is: {user_profile_data['stats']['average_num_questions_entering_circulation_daily']}")
    return user_profile_data

def calculate_total_in_circulation(user_profile_data: dict) -> dict:#Private Function
    '''
    Updates stats.json
    Stat answers: How many questions on average (per day) are being shown to the user?
    Also updates the stat showing the total amount of in_circulation questions == True
    in_circulation stat is by date so it can graphed over time and allow for deriving a stat showing the average number of questions that get changed to in_circulation per day/month/year
    '''    
    # print("def calculate_total_in_circulation(user_profile_data: dict) -> dict")
    todays_date = date.today()
    todays_date = str(todays_date)
    total_in_circulation = 0
    for pile_name, pile in user_profile_data["questions"].items():
        if pile_name != "in_circulation_not_eligible" and pile_name != "in_circulation_is_eligible":
            continue
        total_in_circulation += len(pile) # The total number of questions in these two piles is the total number questions that are in circulation
    user_profile_data["stats"]["current_questions_in_circulation"] = total_in_circulation
        # Two variables the above, shows how many are in circulation right now
        # The variable below is a record of how many were in circulation on any given date
        # now determine first if a date exists at all in the stat:
    if user_profile_data["stats"].get("total_in_circulation_questions") == None:
        # print("total_in_circulation_questions record does not exist, creating entry")
        user_profile_data["stats"]["total_in_circulation_questions"] = {todays_date: total_in_circulation}
    else:
        # print("Updating total_in_circulation_questions")
        user_profile_data["stats"]["total_in_circulation_questions"][todays_date] = total_in_circulation
        # At this point

    # print(f"    Return Values are")
    # print(f"    {user_profile_data['stats']['current_questions_in_circulation']}")
    # print(f"    {user_profile_data['stats']['total_in_circulation_questions']}")
    return user_profile_data

def calculate_average_questions_per_day(user_profile_data: dict) -> dict:#Private Function
    '''
    Returns the average_questions_per_day stat,
    Does not update stats.json
    '''
    # print("def calculate_average_questions_per_day(user_profile_data: dict) -> float")
    average_questions_per_day = 0
    for pile_name, pile in user_profile_data["questions"].items():
        if pile_name != "in_circulation_not_eligible" and pile_name != "in_circulation_is_eligible":
            continue
        for unique_id, question_object in pile.items():
            average_questions_per_day += question_object["average_times_shown_per_day"]
    user_profile_data["stats"]["average_questions_per_day"] = average_questions_per_day

    # print(f"    Return value is {user_profile_data['stats']['average_questions_per_day']}")
    return user_profile_data

def print_and_update_revision_streak_stats(user_profile_data: dict) -> dict:#Private Function
    '''
    Returns stats_data
    Creates a statistic where the key is a number representing the revision streak
    and the value represents the total number of questions that are at that current revision streak
    Revision Streak is part of the formula that determines when each question object will be reviewed again after answering
    '''
    # print("def update_statistics.print_and_update_revision_streak_stats(user_profile_data: dict) -> dict")
    revision_streak_stats = {}
    for pile_name, pile in user_profile_data["questions"].items():
        if pile_name != "in_circulation_not_eligible" and pile_name != "in_circulation_is_eligible":
            continue
        for unique_id, question_object in pile.items():
            revision_streak_value = question_object["revision_streak"]
            if revision_streak_value not in revision_streak_stats:
                revision_streak_stats[revision_streak_value] = 1
            else:
                revision_streak_stats[revision_streak_value] += 1

    # sort the dictionary, so it reads 1-> ∞
    list_of_keys = revision_streak_stats.keys() # make a copy of the keys
    sorted_revision_streak_stats = {}
    list_of_keys = sorted([int(i) for i in list_of_keys])
    for number in list_of_keys:
        number = int(number)
        sorted_revision_streak_stats[number] = revision_streak_stats[number]
    user_profile_data["stats"]["revision_streak_stats"] = sorted_revision_streak_stats
    # Update stats.json with new information
    # print(f"    Revision Streak stats are now: {user_profile_data['stats']['revision_streak_stats']}")
    return user_profile_data

def update_stat_total_questions_in_database(user_profile_data: dict) -> dict:#Private Function
    '''
    Scans the questions database and updates stats with the total number of question objects
    returns stats_data
    '''
    # print("def update_stat_total_questions_in_database(user_profile_data: dict) -> dict")
    todays_date = date.today()
    todays_date = str(todays_date)
    total_questions_in_database = 0
    # Tally up the length of every pile, there are five piles
    for pile_name, pile in user_profile_data["questions"].items():
        total_questions_in_database += len(pile)
    metric = {todays_date: total_questions_in_database}
    if user_profile_data["stats"].get("total_questions_in_database") == None:
        # print("initializing first instance of stat 'total_questions_in_database'")
        user_profile_data["stats"]["total_questions_in_database"] = metric
    else:
        # print("updating total_questions_in_database stat")
        user_profile_data["stats"]["total_questions_in_database"][todays_date] = total_questions_in_database
    # print(f"    Return object has new value {user_profile_data['stats']['total_questions_in_database']}")
    return user_profile_data

def increment_questions_answered(user_profile_data: dict) -> dict:#Private Function
    '''
    Embeds inside the update score function, 
    increments the questions answered stat. 
    Questions answered is stored by date, so the user can see a record of usage over time.
    '''
    stats_data = user_profile_data["stats"]
    # Do not call this within the update_stats function, is only designed to be called while updating the score for a question
    todays_date = str(date.today())
    if stats_data.get("questions_answered_by_date") == None: # First check, if the variable isn't there at all create the questioned answer dict stat
        # print("questions_answered object does not exist, creating entry")
        stats_data["questions_answered_by_date"] = {todays_date: 1}
    elif todays_date not in stats_data["questions_answered_by_date"]: # Second check, if the user hasn't answered a questioned today then todays date will not be in the dictionary
        # print("first question of the day, initializing new key: value for today's date")
        stats_data["questions_answered_by_date"][todays_date] = 1
    else: # No check needed here, if the variable exists and the todays date exists as key we can safely access the key
        # print("incrementing score for today")
        stats_data["questions_answered_by_date"][todays_date] += 1
    stats_data["total_questions_answered"] = sum(stats_data["questions_answered_by_date"].values())

    user_profile_data["stats"] = stats_data
    return user_profile_data