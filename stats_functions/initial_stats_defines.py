from datetime import datetime
def build_first_time_stats_data(user_profile_data: dict = None) -> dict:#Private Function
    '''
    Initial stats for new users
    '''
    stats_data = {}
    stats_data["questions_answered_by_date"] = {f"{datetime.now()}": 0}
    stats_data["total_questions_answered"] = 0
    stats_data["average_questions_per_day"] = 0
    return stats_data
