import flet as ft
import public_functions
import system_data
from lib import helper
class SubjectSettingCard(ft.Row):
    def __init__(self, subject_name, user_profile_data):
        super().__init__()
        self.subject_name       = subject_name
        self.user_profile_data  = user_profile_data

        self.text               = ft.Text(
            value   = str(subject_name).title(),
            width   = 200,
            size    = 16
        )

        self.interest_meter     = ft.TextField(
            value   = self.user_profile_data["settings"]["subject_settings"][subject_name]["interest_level"],
            width = 100,
            on_change=self.update_interest_level
        )

        self.priority_level     = ft.TextField(
            value   = self.user_profile_data["settings"]["subject_settings"][self.subject_name]["priority"],
            width = 100,
            on_change=self.update_priority_level
        )

        self.subject_setting_card = ft.Row(
            width   = 400,
            controls=[
                self.text,
                self.interest_meter,
                self.priority_level
            ]
        )
        self.controls.append(self.subject_setting_card)
    def update_interest_level(self, e):
        try:
            submit_value = int(e.data)
            self.user_profile_data["settings"]["subject_settings"][self.subject_name]["interest_level"] = submit_value
            self.interest_meter.color = ft.colors.GREEN
        except ValueError:
            self.interest_meter.color = ft.colors.RED
    def update_priority_level(self, e):
        try:
            submit_value = int(e.data)
            self.user_profile_data["settings"]["subject_settings"][self.subject_name]["priority"]   = submit_value
            self.priority_level.color = ft.colors.GREEN
        except ValueError:
            self.priority_level.color = ft.colors.RED

class BooleanSettingCard(ft.Row):
    def __init__(self, setting_name, setting_value, user_profile_data):
        super().__init__()
        self.setting_name       = setting_name
        self.setting_value      = setting_value
        self.submission         = self.setting_value
        self.width              = 350
        self.user_profile_data  = user_profile_data
        # Define the Text for this card
        self.text           = ft.Text(
            value = str(self.setting_name).title(),
            width = 200,
            size  = 16
        )        
        if self.setting_name == "is_module_active_by_default":
            self.text.tooltip = "When adding a module to your profile, should the questions that belong to that module be added to your profile by default?\n A value of True will ensure module questions are immediately added by default.\n A value of False means the module will have to be manually activated after adding the module to your profile"
        self.input_box      = ft.Checkbox(
            value=str(self.setting_value),
            on_change=self.update_submission_value,
            width = 50
        )
        # The actual container
        self.setting_card   = ft.Row(
            controls=[
                self.text,
                self.input_box
            ]
        )
        self.controls = [self.setting_card]

    def update_submission_value(self, e):
        try:
            new_value = bool(e.data)
            good_value = True
            print(new_value, e.data)
        except:
            good_value = False
        if good_value != True:
            print("BAD VALUE --->", e.data)
            return None
        if self.setting_name == "is_module_active_by_default":
            self.user_profile_data["settings"]["module_settings"]["is_module_active_by_default"] = e.data
        else:
            print("Invalid setting entered")



class IntegerSettingCard(ft.Row):
    def __init__(self, setting_name, setting_value, user_profile_data):
        super().__init__()
        self.setting_name       = setting_name
        self.setting_value      = setting_value
        self.submission         = self.setting_value
        self.width              = 350
        self.user_profile_data  = user_profile_data
        # Define the Text for this card
        self.text           = ft.Text(
            value = str(self.setting_name).title(),
            width = 200,
            size  = 16
        )
        # Tooltip is conditional based on what the setting is
        if self.setting_name == "time_between_revisions":
            self.text.tooltip = "Governs how far apart the initial spacing of questions are, set a lower value to see questions more often, and a higher value to see individual questions less often"
        elif self.setting_name == "due_date_sensitivity":
            self.text.tooltip = "The amount of time in hours, if the due date is within X amount of hours the question is eligible to be shown: This setting allows questions to be shown more often"
        elif self.setting_name == "desired_daily_questions":
            self.text.tooltip = "How many questions on average should Quizzer attempt to show you? For example, if value is 100, Quizzer will present 100 questions ON AVERAGE to you. Some days might be 80, others might be 120"
        else:
            print("Enter a valid integer based setting")
        # Define the Input box
        self.input_box      = ft.TextField(
            value=str(self.setting_value),
            on_change=self.update_submission_value,
            width = 150
        )

        # The actual container
        self.setting_card   = ft.Row(
            controls=[
                self.text,
                self.input_box
            ]
        )

        self.controls = [self.setting_card]

    def update_submission_value(self, e):
        try:
            if self.setting_name == "time_between_revisions":
                value_to_change = float(e.data)
            else:
                value_to_change = int(e.data)
            self.user_profile_data["settings"][self.setting_name] = value_to_change
            print(self.user_profile_data["settings"][self.setting_name])
        except ValueError:
            print("Invalid value", e.data)