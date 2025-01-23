import flet as ft

class IntegerStat(ft.Container):
    def __init__(self, stat_name, stat_value, user_profile_data):
        super().__init__()
        self.stat_name          = stat_name
        self.stat_value         = stat_value
        self.user_profile_data  = user_profile_data
        self.text = ft.Text(width=250)
        self.stat_display = ft.Text(value = self.stat_value)
        if self.stat_name == "total_questions_answered":
            self.text.value = "Total Questions Answered:"
            self.text.tooltip = "The total amount of questions you've answered over your profile's lifespan"

        elif self.stat_name == "average_questions_per_day":
            self.text.value = "Average Shown Per Day:"
            self.text.tooltip = "The average amount of questions that Quizzer is showing you per day \n For Example if this value is 100 then you could see as little as 50 questions or as much as 150-200 questions in day, but the average will always be 100"

        elif self.stat_name == "current_questions_in_circulation":
            self.text.value = "Current Questions in Circulation:"
            self.text.tooltip = "The Total amount of questions you know the answer to, \nor\n the number of questions quizzer selects from when asking you questions."

        elif self.stat_name == "average_num_questions_entering_circulation_daily":
            self.text.value = "New Questions Daily:"
            self.text.tooltip = "This value represents how many new questions get introduced to you on average per day (the value is based on the last 90 days of usage)"
        elif self.stat_name == "non_circulating_questions":
            self.text.value = "Non Circulating Questions"
            self.text.tooltip = "The number of questions in reserve, The total amount of questions that could be shown to you based on the modules you've activated. When this number hits 0 Quizzer will no longer be able to introduce new material to you. You can raise this value by adding questions or adding new modules from the display modules page"

        elif self.stat_name == "reserve_questions_exhaust_in_x_days":
            self.text.value = "Number of Days before running out of Questions"
            self.text.tooltip = "Tied directly to the Non-Circulating Questions stat, this is the number of days based on your current performance that it will take to introduce all of the material you've selected. If this value hits 0, it means there is nothing left in reserve to introduce. Consider adding new questions are adding new modules from the display modules page"

        else:
            print("ERROR, invalid stat_name passed to class IntegerStat")

        self.card_row = ft.Row(
            alignment=ft.MainAxisAlignment.START,
            controls = [
                self.text,
                self.stat_display
            ]
        )

        self.content = self.card_row