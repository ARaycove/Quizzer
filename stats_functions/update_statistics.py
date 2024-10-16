from lib import helper
from datetime import datetime, date, timedelta
import json
import time
import questions
import settings
import math
# One function per stat should exist
# each function should print the value of that stat to stats.jon
# API Calls should then only need to reference stats.json for statistics information.
#####################################################################################
def update_stat_total_questions_in_database(questions_data, stats_data):#Private Function
    '''
    Scans the questions database and updates stats with the total number of question objects
    returns stats_data
    '''
    todays_date = date.today()
    todays_date = str(todays_date)
    total_questions_in_database = len(questions_data) #Time O(1)
    metric = {todays_date: total_questions_in_database}
    if stats_data.get("total_questions_in_database") == None:
        print("initializing first intance of stat 'total_questions_in_database'")
        stats_data["total_questions_in_database"] = metric
    else:
        # print("updating total_questions_in_database stat")
        stats_data["total_questions_in_database"][todays_date] = total_questions_in_database
    return stats_data
    
def determine_total_eligible_questions(eligibility_index, stats_data):
    '''
    returns stats_data
    calculates based on the index, the total number of eligible questions
    '''
    total_eligible_questions = len(eligibility_index)
    stats_data["current_eligible_questions"] = total_eligible_questions
    return stats_data
    
#####################################################################################
def print_and_update_revision_streak_stats(revision_streak_index, stats_data):#Private Function
    '''
    Returns stats_data
    Creates a statistic where the key is a number representing the revision streak
    and the value represents the total number of questions that are at that current revision streak
    Revision Streak is part of the formula that determines when each question object will be reviewed again after answering
    '''
    revision_streak_stats = {}
    for revision_streak_value, data in revision_streak_index.items():
        revision_streak_stats[revision_streak_value] = len(data)
    list_of_keys = revision_streak_stats.keys() # make a copy of the keys
    sorted_revision_streak_stats = {}
    list_of_keys = sorted([int(i) for i in list_of_keys])
    for number in list_of_keys:
        number = int(number)
        sorted_revision_streak_stats[number] = revision_streak_stats[number]
    stats_data["revision_streak_stats"] = sorted_revision_streak_stats
    # Update stats.json with new information
    return stats_data
    
    
    
#####################################################################################
def update_number_of_questions_by_subject(questions_data, settings_data, subject_question_index, subject_in_circulation_index):#Private Function
    '''
    returns settings_data
    This stat calculates how many questions are in_circulation within a given subject
    This stat calculates how many questions in total are within a given subject
    data is written to settings.json
    Function returns None
    '''
    #NOTE Old code was twice as long, inclusion of index allowed the operation to be quicker and more readable
    settings_data = settings.initialize_subject_settings(settings_data, subject_question_index)
    update_data = {}
    initial_subject_setting = {}
    initial_subject_setting["total_questions"] = 0
    initial_subject_setting["num_questions_in_circulation"] = 0
    # settings_data =
    for subject in settings_data["subject_settings"].keys():
        total_activated = 0
        try:
            total_count = len(subject_question_index[subject])
        except KeyError:
            total_count = 0
        for unique_id, question_object in questions_data.items():
            try:
                activated = settings_data["is_module_activated"][question_object["module_name"]]
            except KeyError: # The question_object references a module that doesn't exist, assume that the question should not be put into circulation and is not activated
                activated = False
            if subject in question_object["subject"] and activated == True:
                total_activated += 1
        try:
            in_circulation_count = len(subject_in_circulation_index[subject])
        except KeyError as e:
            in_circulation_count = 0
        settings_data["subject_settings"][subject]["total_questions"] = total_count
        settings_data["subject_settings"][subject]["num_questions_in_circulation"] = in_circulation_count
        settings_data["subject_settings"][subject]["total_activated_questions"] = total_activated # total number of questions whose parent module is active
        if total_activated == in_circulation_count:
            settings_data["subject_settings"][subject]["has_available_questions"] = False
        else:
            settings_data["subject_settings"][subject]["has_available_questions"] = True
        # print(f"{subject.title():25} has {in_circulation_count:5}/{total_count:<5} currently in circulation")
    settings_data["subject_settings"] = helper.sort_dictionary_keys(settings_data["subject_settings"])
    return settings_data
    
    
    


#####################################################################################
def calculate_average_questions_per_day(questions_data):#Private Function
    '''
    Returns the average_questions_per_day stat,
    Does not update stats.json
    '''
    average_questions_per_day = 0
    for question in questions_data:
        if question["in_circulation"] == True:
            average_questions_per_day += question["average_times_shown_per_day"]
    return average_questions_per_day

def initialize_and_update_questions_exhausted_in_x_days_stat(questions_data, stats_data):
        count = 0
        for unique_id, question in questions_data.items():
            if question["in_circulation"] == False:
                    count += 1              
        questions_not_in_circulation = count
        stats_data["non-circulating_questions"] = questions_not_in_circulation
        # The number of questions that are not in circulation divided by the average amount of questions that get put into circulation gives us the amount of days until there are no more questions left to add based on user performance
        # Figure can also be used to determine when the user will learn all of the material currently in their database
        if stats_data["average_num_questions_entering_circulation_daily"] != 0:
            stats_data["reserve_questions_exhaust_in_x_days"] = questions_not_in_circulation / stats_data["average_num_questions_entering_circulation_daily"]
        else:
            stats_data["reserve_questions_exhaust_in_x_days"] = 0
        # print(f"Number left to add is {questions_not_in_circulation}")
        # print(f"Average amount being added is {stats_data['average_num_questions_entering_circulation_daily']}")
        # print(f"User will get through all material in {stats_data['reserve_questions_exhaust_in_x_days']} days")
        return stats_data
######################################################################################
# Statistics that involve dates and figures (able to be graphed visually)
######################################################################################
def increment_questions_answered(stats_data):#Private Function
    '''
    Embeds inside the update score function, 
    increments the questions answered stat. 
    Questions answered is stored by date, so the user can see a record of usage over time.
    '''
    # Do not call this within the update_stats function, is only designed to be called while updating the score for a question
    todays_date = str(date.today())
    if stats_data.get("questions_answered_by_date") == None: # First check, if the variable isn't there at all create the questioned answer dict stat
        print("questions_answered object does not exist, creating entry")
        stats_data["questions_answered_by_date"] = {todays_date: 1}
    elif todays_date not in stats_data["questions_answered_by_date"]: # Second check, if the user hasn't answered a questioned today then todays date will not be in the dictionary
        print("first question of the day, initializing new key: value for today's date")
        stats_data["questions_answered_by_date"][todays_date] = 1
    else: # No check needed here, if the variable exists and the todays date exists as key we can safely access the key
        print("incrementing score for today")
        stats_data["questions_answered_by_date"][todays_date] += 1
    stats_data["total_questions_answered"] = sum(stats_data["questions_answered_by_date"].values())
    return stats_data
    
#####################################################################################    
# def update_average_questions_per_day():#Private Function
#     '''
#     Updates stats.json
#     Stat answers: How many questions on average (per day) are being shown to the user?
#     Also updates the stat showing the total amount of in_circulation questions == True
#     in_circulation stat is by date so it can graphed over time and allow for deriving a stat showing the average number of questions that get changed to in_circulation per day/month/year
#     '''
#     questions_data = helper.get_question_data()
#     stats = helper.get_stats_data()
#     average = 0
#     count = 0
#     for qa in questions_data:
#         if qa["in_circulation"] == True:
#             qa["average_times_shown_per_day"] = 1 / math.pow(qa["time_between_revisions"], qa["revision_streak"])
#             average += qa["average_times_shown_per_day"]
#             count += 1
#     # average stat is updated
#     stats["average_questions_per_day"] = average
#     # now determine first if a date exists at all in the stat:
#     stats["current_questions_in_circulation"] = count
    
    
#     helper.update_stats_json(stats)
############################################################################################3
def update_average_questions_per_day(questions_data, stats_data):#Private Function
    '''
    Updates stats.json
    Stat answers: How many questions on average (per day) are being shown to the user?
    Also updates the stat showing the total amount of in_circulation questions == True
    in_circulation stat is by date so it can graphed over time and allow for deriving a stat showing the average number of questions that get changed to in_circulation per day/month/year
    '''
    todays_date = date.today()
    todays_date = str(todays_date)
    average = 0
    count = 0
    for unique_id, qa in questions_data.items():
        if qa["in_circulation"] == True:
            # recalculating makes this redundant, since it's already been calculated
            # qa["average_times_shown_per_day"] = 1 / math.pow(qa["time_between_revisions"], qa["revision_streak"])
            average += qa["average_times_shown_per_day"]
            count += 1
    # average stat is updated
    stats_data["average_questions_per_day"] = average
    stats_data["current_questions_in_circulation"] = count
    # Two variables the above, shows how many are in circulation right now
    # The variable below is a record of how many were in circulation on any given date
    # now determine first if a date exists at all in the stat:
    if stats_data.get("total_in_circulation_questions") == None:
        print("total_in_circulation_questions record does not exist, creating entry")
        stats_data["total_in_circulation_questions"] = {todays_date: count}
    else:
        # print("Updating total_in_circulation_questions")
        stats_data["total_in_circulation_questions"][todays_date] = count
    # At this point 
    return stats_data
    
def calculate_average_num_questions_entering_circulation(stats_data):
    '''
    Stat represents how many questions in total over the span of num_days are getting their in_circulation value set to True
    That is, how many new questions per day on average is the user being shown?
    Stat helps to determine user pacing and how quickly they are learning new things
    '''
    # It is my hope that development of a more advanced algorithm can increase this pace, but for now we can track speed of learning:
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
        average_num_daily = 0
    stats_data["average_num_questions_entering_circulation_daily"] = average_num_daily
    return stats_data