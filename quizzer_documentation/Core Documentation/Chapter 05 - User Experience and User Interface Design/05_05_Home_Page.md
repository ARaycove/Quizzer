# Main Interface 
Upon logging in the user should get sent directly into the main interface of the program. This interface will be the core Answer Questions behavioral task defined in [[03_06_Task_03_Answer_Questions]]. The user will be presented with a question, the center of the screen should be one large button, when clicked the interface should show an animation depicting a "card flipping over to the other side", where the card is the center button, then the answer to that question should appear. At the bottom of the page will be 5 buttons (Yes(sure), Yes(unsure), (?), No(sure), No(unsure)) to reflect the options in the Answer Questions behavioral task. Clicking the center button should bring up three additional options to select. (Did not Read Question Properly), (Not Interested In This), (Too Advanced for Me)
## Globals
Should make use of the following global variables for data consistency when switching pages, but also to help guide the program:
current_question = ...
- Keeps track of the current question the user is engaging with, that way it can remain there when navigating other menus. This should just be the question_answer_reference, also called the question_id. Which can be used to gather contents of the question-answer pair
has_been_flipped = ...
- Helps to keep track of whether the buttons should be enabled or disabled, while also serving to track whether the answer or question should be displayed on the central button
## Rule of Thumb
- Top Bar should use the navigation bar element
- Bottom Bar should use the bottom bar element
- Bottom and Top Bar should be static on the screen
- The center of the screen should scroll if the content of the box exceeds the height of the screen
- Home page should keep an internal record of quickly it took to answer the displayed question
	- The timer starts when the question is displayed
	- The timer stops when the center button is first flipped
	- When the timer stops the elapsed time is recorded and stored. This will be sent to the [[07_12_answerQuestionAnswerPair(status, elapsed_time)|answerQuestionAnswerPair(status, elapsed_time)]] as the second argument whenever the response is entered.
## Images
- Quizzer Logo should be displayed prominently in the center of the screen as the background.
- Quzzer Logo background should be grayscaled and blend into the black background
## Fields
- Flag Question TextField
	- This field appears when the flag question button is pressed, otherwise is not shown
## Buttons
- Menu button
	- Should redirect to the [[05_06_Menu_Page|Menu Page]]
	- Should be place in the top leftmost corner of the app-bar
	- Should not exceed 20px in height
	- Should use the hamburger menu icon
- Flag Question button
	- Should display a pop-up window that allows the user to flag the question as invalid. Pop-up window will have a textfield entry.
	- When submitted will enter the question-answer pair and the comment into the 
	- Should be located in the top rightmost corner of the app-bar
	- calls the [[07_13_flagQuestionAnswerPair(comment)|flagQuestionAnswerPair(comment)]] with the text that was entered
#### Response Buttons
All response buttons should follow a pattern where they begin as disabled, not allowing the user to click on them. The question should be displayed from the get_next question function. when the question button is clicked the animation will play and display the answer. At this point the answer is displayed the buttons should become enabled. Once an option is submitted the buttons should disabled again then the next question get's displayed.
- Yes(sure)
	- question-answer response button
	- Calls [[07_12_answerQuestionAnswerPair(status, elapsed_time)|answerQuestionAnswerPair(status, elapsed_time)]] with status code "yes_sure"
- Yes(unsure)
	- question-answer response button
	- Calls [[07_12_answerQuestionAnswerPair(status, elapsed_time)|answerQuestionAnswerPair(status, elapsed_time)]] with status code "yes_unsure"
- Other
	- question-answer response button
	- returns a pop window with three additional buttons, that take up 1/3 of the center button container ("Did not read the Question . . . Whoops", "This is TOO ADVANCED for me", and "Just not interested in learning this")
	- The pop up window will be separated into fifths, the first fifth will be the "Did not read the Question. . . Whoops" button with a green background matching the logo
	- The second fifth will be empty
	- The third fifth will be the "This is TOO ADVANCED for me" button with the same green background
	- The fourth fifth will be empty
	- the fifth fifth will be the "Just not interested in learning this"
- No(unsure)
	- question-answer response button
	- Calls [[07_12_answerQuestionAnswerPair(status, elapsed_time)|answerQuestionAnswerPair(status, elapsed_time)]] with status code "no_unsure"
- No(sure)
	- question-answer response button
	- Calls [[07_12_answerQuestionAnswerPair(status, elapsed_time)|answerQuestionAnswerPair(status, elapsed_time)]] with status code "no_sure"
- "Did not read the Question. . . Whoops" button
	- question-answer response button
	- Calls [[07_12_answerQuestionAnswerPair(status, elapsed_time)|answerQuestionAnswerPair(status, elapsed_time)]] with status code "did_not_read"
- "This is TOO ADVANCED for me" button
	- question-answer response button
	- Calls [[07_12_answerQuestionAnswerPair(status, elapsed_time)|answerQuestionAnswerPair(status, elapsed_time)]] with status code "too_advanced"
- "Just not interested in learning this"
	- question-answer response button
	- Calls [[07_12_answerQuestionAnswerPair(status, elapsed_time)|answerQuestionAnswerPair(status, elapsed_time)]] with status code "not_interested"


The old home page contains some of these elements:
```dart
import flet as ft
import random
import system_data
import generate_quiz
import system_data_user_stats
from datetime import datetime, date, timedelta

class HomePage(ft.View):
    def __init__(self, page: ft.Page, 
                 questions_available_to_answer, 
                 current_question,
                 current_question_id,
                 question_object_data: dict,
                 user_profile_data: dict,
                 CURRENT_USER,CURRENT_UUID, 
                 currently_displayed, 
                 has_seen, 
                 pages_visited: list,
                 ) -> None:
        super().__init__()
        # CONSTRUCT THE PAGE
        # Assign passed globals to instance
        print(f"Received, {current_question}, {current_question_id}")
        print(f"Received, {user_profile_data.keys()}")
        self.questions_available_to_answer  = questions_available_to_answer
        self.user_profile_data              = user_profile_data
        self.question_object_data           = question_object_data
        self.current_question               = current_question
        self.current_question_id            = current_question_id
        self.CURRENT_USER                   = CURRENT_USER
        self.CURRENT_UUID                   = CURRENT_UUID
        self.currently_displayed            = currently_displayed
        self.has_seen                       = has_seen
        self.pages_visited                  = pages_visited
        self.amount_of_rs_one_questions     = 1
        self.question_presented_time        = datetime.now()
        self.question_answered_time         = None
        self.time_taken_to_answer           = None
        self.has_been_flipped               = False

        ############################################################
        # Define General Data
        self.page               = page
        self.page.title         = "Quizzer - Main Interface"
        self.page.theme_mode    = ft.ThemeMode.DARK
        self.ticker             = 0
        self.page.window_width  = 600
        self.page.window_height = self.page.window_max_height

        self.stat_list = []
        ############################################################
        # Define Any Icons
        self.menu_icon      = ft.Icon(name=ft.Icons.MENU_SHARP, color=ft.Colors.BLACK)
        self.yes_icon       = ft.Icon(name=ft.Icons.CHECK_CIRCLE, color=ft.Colors.WHITE)
        self.no_icon        = ft.Icon(name=ft.Icons.NOT_INTERESTED, color=ft.Colors.WHITE)
        self.skip_icon      = ft.Icon(name=ft.Icons.REPEAT, color=ft.Colors.BLACK)
        self.plus_icon      = ft.Icon(name=ft.Icons.ADD, color=ft.Colors.BLACK)
        self.edit_icon      = ft.Icon(name=ft.Icons.EDIT, color=ft.Colors.BLACK)
        ############################################################
        # Define UI components
        #   Home Page has 7 total "buttons"
        #   Home Page has 10 Components that get displayed (including the 7 buttons)
        self.menu_button                    = ft.ElevatedButton(
            content=self.menu_icon, 
            bgcolor="white", 
            on_click=self.go_to_menu_page)

        self.add_new_question_button        = ft.IconButton(
            icon        = ft.Icons.ADD,
            icon_color  = ft.Colors.BLACK,
            tooltip     = "Add A New Question",
            bgcolor     = ft.Colors.WHITE,
            on_click=self.go_to_add_question_page
            )

        self.edit_current_question_button   = ft.IconButton(
            icon        = ft.Icons.EDIT,
            icon_color  = ft.Colors.BLACK,
            tooltip     = "Edit the current question",
            bgcolor     = ft.Colors.WHITE,
            on_click=self.go_to_edit_question_page
        )

        self.correct_button                 = ft.ElevatedButton(
            content     = self.yes_icon,
            bgcolor     = "green",
            on_click    = lambda e: self.question_answered(e, status="correct"),
            disabled    = True
        )

        self.skip_button                    = ft.ElevatedButton(
            content     = self.skip_icon,
            bgcolor     = "white",
            on_click    = self.skip_to_next_question,
            disabled    = False
        )

        self.incorrect_button               = ft.ElevatedButton(
            content     = self.no_icon,
            bgcolor     = "red",
            on_click    = lambda e: self.question_answered(e , status="incorrect"),
            disabled    = True
        )
        
        self.text_object           = ft.Text(value="",text_align="left")
        self.image_object          = ft.Image(src=f"system_data/media_files/")
        self.image_object.width    = 500
        self.image_object.height   = 500
        ############################################################
        # Define Composite Components -> rely on above container elements and data
        self.main_page_qo_text_row          = ft.Row(
            expand      =   True,
            # alignment   =   ft.MainAxisAlignment.CENTER,
            controls    =   [
                self.text_object
            ],
            wrap=True
        )
        self.main_page_qo_image_row         = ft.Row(
            # alignment   =   ft.MainAxisAlignment.CENTER,
            controls    =   [
                self.image_object
            ],
            alignment=ft.MainAxisAlignment.CENTER
        )
        self.main_page_qo_audio_row         = ft.Row(
            expand      =   True,
            # alignment   =   ft.MainAxisAlignment.CENTER,
            controls    =   [
                
            ]
        )
        self.main_page_qo_video_row         = ft.Row(
            expand      =   True,
            # alignment   =   ft.MainAxisAlignment.CENTER,
            controls    =   [
                
            ]
        )

        #FIXME Audio and Video not supported currently
        self.main_page_question_object_data = ft.Column(
            alignment=ft.MainAxisAlignment.CENTER,
            horizontal_alignment=ft.CrossAxisAlignment.CENTER,
            controls=[self.main_page_qo_text_row,
                    self.main_page_qo_image_row
                    ] 
        )
        
        self.question_object_display_button = ft.Container(
            padding=20,
            ink=True,
            ink_color=ft.Colors.GREY_500,
            content=self.main_page_question_object_data,
            on_click=self.flip_question_answer
        )

        ############################################################        
        # Define Container elements for organization
        #   Contains three rows, one embedded row
        self.row_one = ft.Row(
            alignment=ft.MainAxisAlignment.END,
            controls=[
                self.add_new_question_button,
                self.edit_current_question_button
            ]
        )
        # Statistics
        self.todays_date = str(date.today())
        self.remaining_questions_counter = ft.Text(
            tooltip="The amount of questions remaining to be answered,\n When this value hits zero, Quizzer will determine if it will put more questions in front of you."
        )
        self.total_answered_today = ft.Text(
            tooltip="This number represents the amount of questions you've answered just for today"
        )
        self.average_questions_per_day = ft.Text(
            tooltip="The current average amount of questions Quizzer is showing you per day"
        )
        self.first_row = ft.Row(
            alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
            controls=[
                self.menu_button,
                self.remaining_questions_counter,
                self.total_answered_today,
                self.average_questions_per_day,
                self.row_one
            ],
            height  = 50
        )

        self.middle_row = ft.Column(
            alignment=ft.MainAxisAlignment.CENTER,
            controls=[
                self.question_object_display_button
            ],
            expand  = True
        )

        self.bottom_row = ft.Row(
            alignment=ft.MainAxisAlignment.SPACE_AROUND,
            controls=[
                self.correct_button,
                self.skip_button,
                self.incorrect_button
            ],
            height=50
        )
        ############################################################
        # Piece it all together with self.controls
        self.controls=[
            self.first_row,
            self.middle_row,
            self.bottom_row
        ]
        self.vertical_alignment     = ft.MainAxisAlignment.SPACE_BETWEEN
        self.horizontal_alignment   = ft.MainAxisAlignment.SPACE_AROUND
        self.answer_ticker          = 0
        self.build_initial_state()

    # Page Functionality below:
    def go_to_menu_page(self, e):
        self.page.go("/Menu")
    def go_to_add_question_page(self, e):
        self.page.go("/AddQuestionPage")
    def go_to_edit_question_page(self,e):
        self.page.go("/EditQuestionPage")
    def go_to_display_modules_page             (self, e: ft.ControlEvent = None):
        self.page.go("/DisplayModulePage")

    def build_initial_state(self):
        self.remaining_questions_counter.value  = str(f"Rem: {len(self.user_profile_data['questions']['in_circulation_is_eligible'])}")
        self.average_questions_per_day.value    = str(f"APD: {self.user_profile_data["stats"]["average_questions_per_day"]:.3f}")
        try:
            self.total_answered_today.value = str(f"TAT:{self.user_profile_data['stats']['questions_answered_by_date'][self.todays_date]}")
        except KeyError: # If the user just logged in today, that entry won't exist so we need to update stats first
            # Total is 0, the entry is made when the first question is answered
            system_data.update_stats(self.user_profile_data,self.question_object_data)
            self.total_answered_today.value = "0"
            # Current question is residing in the is_eligible pile, use this one, otherwise get a new question
        self.user_profile_data["questions"] = system_data.sort_questions(self.user_profile_data, self.question_object_data)
        self.get_next_question()

        if self.questions_available_to_answer == False:
            return None
        # Execute these if there are available questions
        self.currently_displayed == "question"
        self.text_object.value  = self.current_question["question_text"]
        self.text_object.size   = 16
        self.image_object.src   = f"system_data/media_files/{self.current_question['question_image']}"
        self.question_object_display_button.height = (self.page.height - 125)
        self.user_profile_data  = system_data.update_stats(self.user_profile_data,self.question_object_data)
        self.page.update()

    def verify_if_remaining_questions(self) -> bool:
        '''
        Checks if there are any remaining questions,
        If there are remaining questions then, we will fetch them,
        If False, then we will set the display to read a message for the user
        '''
        # We can look directly at the in_circulation_is_eligible_pile:
        current_eligible_questions = len(self.user_profile_data["questions"]["in_circulation_is_eligible"])
        if current_eligible_questions <= 0:
            self.user_profile_data["settings"]["subject_settings"] = system_data.build_subject_settings(
                self.user_profile_data, 
                self.question_object_data)
            # Go through the non_eligible questions to see if anything is eligible now
            self.user_profile_data["questions"] = system_data.sort_questions(self.user_profile_data, self.question_object_data)
            current_eligible_questions = len(self.user_profile_data["questions"]["in_circulation_is_eligible"])
        # Get new questions to put into circulation if no eligible questions to answer
        if current_eligible_questions <= 0:
            self.answer_ticker = 0 # reset ticker
            self.user_profile_data = generate_quiz.update_questions_in_circulation(
                self.user_profile_data,
                self.question_object_data
            )
        # Get new questions to put into circulation every 25 questions answered
        elif self.answer_ticker >= 25:
            self.answer_ticker = 0
            self.user_profile_data = generate_quiz.update_questions_in_circulation(
                self.user_profile_data,
                self.question_object_data
            )
            # Call to the server everytime we run out of questions
        system_data.update_user_profile(self.user_profile_data)
        # After these checks we should have new questions available,
        #   If the value is still 0 then we have no new questions to introduce
        current_eligible_questions = len(self.user_profile_data["questions"]["in_circulation_is_eligible"])
        if current_eligible_questions <= 0:
            self.questions_available_to_answer = False
            self.text_object.value  = "No Remaining questions left to answer, come back later\nTry adding in a new module, adding your own questions, or increasing the daily questions in your settings"
            self.image_object.src   = "system_data/no_file.png"
        else:
            self.questions_available_to_answer = True

    def get_next_question(self):
        # print(f"def get_next_question()")
        # If the question list has no questions in it, attempt to fill it again
        self.verify_if_remaining_questions()
        if self.questions_available_to_answer == True:
            # self.current_question_id = random.choice(list(self.user_profile_data["questions"]["in_circulation_is_eligible"].keys()))
            self.current_question_id = system_data.get_next_question(self.user_profile_data,
                                                                     amount_of_rs_one_questions=self.amount_of_rs_one_questions)
            self.current_question    = self.question_object_data[self.current_question_id].copy()
        self.question_presented_time = datetime.now()
        self.question_answered_time  = datetime.now()
        self.page.update()

    def question_answered(self, e: ft.ControlEvent, status):
        '''
        Calls backend update_score function with status of correct
        '''
        # print(f"def question_answered(e: ft.ControlEvent, status: int) -> None")
        self.correct_button.disabled    = True
        self.incorrect_button.disabled  = True
        self.has_been_flipped           = False # Since we got a new question, the new question has not been flipped:
        self.page.update()
        # print(f"    Updating question <{self.current_question_id}> with status of <{status}>")
        self.time_taken_to_answer   = self.question_answered_time -self.question_presented_time
        if self.time_taken_to_answer.total_seconds() == 0:
            self.time_taken_to_answer = None
        self.user_profile_data = system_data.update_score(
            status                      = status,
            unique_id                   = self.current_question_id,
            user_profile_data           = self.user_profile_data,
            question_object_data        = self.question_object_data,
            time_spent                  = self.time_taken_to_answer
        )
        if status == "correct": # only increment on correct answers, this mechanism helps define when new questions are introduced
            self.answer_ticker += 1
        self.get_next_question()
        if self.questions_available_to_answer == True:
            self.text_object.value          = self.current_question["question_text"]
            self.image_object.src           = f"system_data/media_files/{self.current_question['question_image']}"
        self.currently_displayed        = "question"
        self.has_seen = False
        self.skip_button.disabled=False
        system_data.update_user_profile(self.user_profile_data)
        self.remaining_questions_counter.value  = str(f"Rem: {len(self.user_profile_data['questions']['in_circulation_is_eligible'])}")
        self.total_answered_today.value         = str(f"TAT:{self.user_profile_data['stats']['questions_answered_by_date'][self.todays_date]}")
        self.average_questions_per_day.value    = str(f"APD: {self.user_profile_data["stats"]["average_questions_per_day"]:.3f}")
        print("Current Learning Rate Questions per day:", self.user_profile_data["stats"]["average_num_questions_entering_circulation_daily"])
        yesterday = date.today() - timedelta(1)
        if self.user_profile_data["stats"]["total_in_circulation_questions"].get(str(yesterday)) == None:
            self.user_profile_data["stats"]["total_in_circulation_questions"][str(yesterday)] = self.user_profile_data["stats"]["total_in_circulation_questions"][str(date.today())]
        print("Yesterday's num questions in circulation:   ", self.user_profile_data["stats"]["total_in_circulation_questions"][str(yesterday)])
        print("Current     num questions in circulation:   ", self.user_profile_data["stats"]["total_in_circulation_questions"][str(date.today())])
        difference = self.user_profile_data["stats"]["total_in_circulation_questions"][str(date.today())] - self.user_profile_data["stats"]["total_in_circulation_questions"][str(yesterday)]
        print(f"Amount Learned so far today:                 {difference}")
        self.amount_of_rs_one_questions = self.user_profile_data["stats"]["revision_streak_stats"].get(1)
        self.page.update()

    def skip_to_next_question(self, e: ft.ControlEvent):
        '''
        Changed semantically to a re-do button, low confidence correct answer
        Will now increment only number of questions answered, but does not modify the object itself
        '''
        self.skip_button.disabled=True
        self.page.update()
        self.user_profile_data = system_data_user_stats.increment_questions_answered(self.user_profile_data)
        status = "repeat"
        self.time_taken_to_answer   = self.question_answered_time - self.question_presented_time 
        self.user_profile_data = system_data.update_score(
            status,
            self.current_question_id,
            self.user_profile_data,
            self.question_object_data
        )
        self.get_next_question()
        if self.questions_available_to_answer == True:
            self.text_object.value          = self.current_question["question_text"]
            self.image_object.src           = f"system_data/media_files/{self.current_question['question_image']}"
        self.currently_displayed        = "question"
        self.has_seen = False
        self.skip_button.disabled=False
        self.page.update()

    def flip_question_answer(self, e):
        # After a question is presented, the call of this funciton indicates that the question has been answered. Therefore on the initial answering we will record the time at this point
        if self.has_been_flipped == False:
            self.question_answered_time = datetime.now()
            self.has_been_flipped = True
        
        if self.questions_available_to_answer == False:
            self.page.update()
            return False
        if      self.currently_displayed            == "question":
            self.text_object.value      = self.current_question["answer_text"]
            self.image_object.src       = f"system_data/media_files/{self.current_question['answer_image']}"
            self.currently_displayed    = "answer"
        elif    self.currently_displayed            == "answer":
            self.text_object.value      = self.current_question["question_text"]
            self.image_object.src       = f"system_data/media_files/{self.current_question['question_image']}"
            self.currently_displayed    = "question"
        else:
            print("Hardcoded variable has different value than expected?")
            raise ValueError
        
        # Enable the buttons for answers since we've flipped at least once
        self.correct_button.disabled    =   False
        self.incorrect_button.disabled  =   False
        self.page.update()
```