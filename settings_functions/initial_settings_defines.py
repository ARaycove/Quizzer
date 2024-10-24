from settings_functions import settings
def build_first_time_settings_data(user_profile_data, question_object_data) -> dict:
    settings_data = {}
    settings_data["quiz_length"] = 25
    settings_data["time_between_revisions"] = 1.2
    settings_data["due_date_sensitivity"] = 12
    settings_data["vault_path"] = ["enter/path/to/obsidian/vault"]
    settings_data["desired_daily_questions"] = 50
    user_profile_data["settings"] = settings_data
    settings_data["subject_settings"] = settings.build_subject_settings(user_profile_data, question_object_data)
    settings_data["module_settings"] = settings.build_module_settings(user_profile_data, question_object_data)
    return settings_data