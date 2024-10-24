
from stats_functions import update_statistics
from settings_functions import settings
##########################################################################################
# Calculation functions:
##########################################################################################

##########################################################################################
# Master call function
##########################################################################################
def update_stats(user_profile_data: dict, question_object_data: dict) -> dict:#Private Function
    user_profile_data = update_statistics.update_stat_total_questions_in_database(user_profile_data)
    user_profile_data = update_statistics.print_and_update_revision_streak_stats(user_profile_data)
    user_profile_data["settings"]["subject_settings"] = settings.build_subject_settings(user_profile_data, question_object_data)
    user_profile_data = update_statistics.calculate_average_questions_per_day(user_profile_data)
    user_profile_data = update_statistics.calculate_total_in_circulation(user_profile_data)
    user_profile_data = update_statistics.calculate_average_num_questions_entering_circulation(user_profile_data)
    user_profile_data = update_statistics.initialize_and_update_questions_exhausted_in_x_days_stat(user_profile_data)
    user_profile_data = update_statistics.determine_total_eligible_questions(user_profile_data)
    return user_profile_data