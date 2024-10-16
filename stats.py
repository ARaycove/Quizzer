import json
import math
import settings
import questions
from stats_functions import update_statistics
from lib import helper
import questions
from datetime import date, datetime
##########################################################################################
# Calculation functions:
##########################################################################################
def initialize_first_time_stats():#Private Function
    '''
    Just ensures that there is something inside the stats.json file
    '''
    user_profile_name = helper.get_instance_user_profile()
    stats = {}
    stats["questions_answered_by_date"] = {f"{datetime.now()}": 0}
    stats["total_questions_answered"] = 0
    stats["average_questions_per_day"] = 0 # just a place holder value, once update_system_data is called this value will be overwritten with an accurate figure
    with open(f"user_profiles/{user_profile_name}/json_data/stats.json", "w+") as f:
        json.dump(stats, f)
##########################################################################################
def initialize_stats_json():
    '''
    Health check function, if the stats.json file is missing then function will create and initialize stats.json with default data
    '''
    try:
        helper.get_stats_data()
        print("stats.json already exists")
    except FileNotFoundError:
        print("stats.json not found")
        print("creating stats.json with default values")
        initialize_first_time_stats()
##########################################################################################
# Master call function
##########################################################################################
def update_stats(questions_data, stats_data, settings_data, revision_streak_index, eligiblity_index, subject_question_index, subject_in_circulation_index):#Private Function
    # the update_system_data() calls this function
    # This function is only for updating statistical data
    # One function call per stat
    stats_data = update_statistics.update_stat_total_questions_in_database(questions_data, stats_data)
    stats_data = update_statistics.print_and_update_revision_streak_stats(revision_streak_index, stats_data)
    settings_data = update_statistics.update_number_of_questions_by_subject(questions_data, settings_data, subject_question_index, subject_in_circulation_index)
    stats_data = update_statistics.update_average_questions_per_day(questions_data, stats_data)
    stats_data = update_statistics.calculate_average_num_questions_entering_circulation(stats_data)
    stats_data = update_statistics.initialize_and_update_questions_exhausted_in_x_days_stat(questions_data, stats_data)
    stats_data = update_statistics.determine_total_eligible_questions(eligiblity_index, stats_data)
    # shuffle order of questions_data before writing it back to LTS
    helper.shuffle_dictionary_keys(questions_data)
    helper.update_stats_json(stats_data)
    helper.update_settings_json(settings_data)
    helper.update_questions_json(questions_data)
    returned_data = {}
    returned_data["questions_data"] = questions_data
    returned_data["stats_data"] = stats_data
    returned_data["settings_data"] = settings_data
    returned_data["eligibility_index"] = eligiblity_index
    returned_data["questions_by_subject_index"] = subject_question_index
    return returned_data