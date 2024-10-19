import json
import math
from settings_functions import settings
from question_functions import questions, update_questions
from stats_functions import update_statistics
from lib import helper
from datetime import date, datetime
##########################################################################################
# Calculation functions:
##########################################################################################

##########################################################################################
# Master call function
##########################################################################################
def update_stats(user_profile_data: dict) -> dict:#Private Function
    # Old List: questions_data, stats_data, settings_data, revision_streak_index, eligiblity_index, subject_question_index, subject_in_circulation_index
    # the update_system_data() calls this function
    # This function is only for updating statistical data
    # One function call per stat
    user_profile_data = update_statistics.update_stat_total_questions_in_database(user_profile_data) #FIXME
    user_profile_data = update_statistics.print_and_update_revision_streak_stats(user_profile_data) #FIXME
    user_profile_data = update_statistics.update_number_of_questions_by_subject(user_profile_data) #FIXME
    user_profile_data = update_statistics.update_average_questions_per_day(user_profile_data) #FIXME
    user_profile_data = update_statistics.calculate_average_num_questions_entering_circulation(user_profile_data) #FIXME
    user_profile_data = update_statistics.initialize_and_update_questions_exhausted_in_x_days_stat(user_profile_data) #FIXME
    user_profile_data = update_statistics.determine_total_eligible_questions(user_profile_data) #FIXME
    # shuffle order of questions_data before writing it back to LTS
    questions_data = user_profile_data["questions"]
    questions_data = helper.shuffle_dictionary_keys(questions_data)
    user_profile_data["questions"] = questions_data
    helper.update_user_profile(user_profile_data)
    return user_profile_data