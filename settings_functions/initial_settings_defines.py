def build_first_time_settings_data(user_profile_data: dict = None) -> dict: #Private Function
    settings = {}
    settings["quiz_length"] = 25
    settings["time_between_revisions"] = 1.2
    settings["due_date_sensitivity"] = 12
    settings["vault_path"] = ["enter/path/to/obsidian/vault"]
    settings["desired_daily_questions"] = 50
    return settings