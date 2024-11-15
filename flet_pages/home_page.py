import flet as ft
import random
import system_data
import generate_quiz
from datetime import datetime, date, timedelta

class HomePage(ft.View):
    def __init__(self, page: ft.Page, questions_available_to_answer, 
                 current_question,current_question_id,question_object_data,
                 user_profile_data,CURRENT_USER,CURRENT_UUID, 
                 currently_displayed, has_seen, pages_visited) -> None:
        super().__init__()
        # CONSTRUCT THE PAGE
        # Assign passed globals to instance
        print(f"Received, {current_question}, {current_question_id}")
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

        ############################################################
        # Define General Data
        self.page               = page
        self.page.title         = "Quizzer - Main Interface"

        # # Question fields
        # self.question_text      = self.current_question["question_text"]
        # self.question_image     = self.current_question["question_image"]
        # self.question_audio     = self.current_question["question_audio"]
        # self.question_video     = self.current_question["question_video"]

        # self.answer_text        = self.current_question["answer_text"]
        # self.answer_image       = self.current_question["answer_image"]
        # self.answer_audio       = self.current_question["answer_audio"]
        # self.answer_video       = self.current_question["answer_video"]

        
        # self.text_field                     = "There are no Questions to Display"
        # self.image_field                    = None
        # self.audio_field                    = None
        # self.video_field                    = None

        # if self.currently_displayed == "question":
        #     self.text_field                     = self.question_text
        #     self.image_field                    = self.question_image
        #     self.audio_field                    = self.question_audio
        #     self.video_field                    = self.question_video
        # elif self.currently_displayed == "answer":
        #     self.text_field                     = self.answer_text
        #     self.image_field                    = self.answer_image
        #     self.audio_field                    = self.answer_audio
        #     self.video_field                    = self.answer_video

        self.stat_list = []
        ############################################################
        # Define Any Icons
        self.menu_icon      = ft.Icon(name=ft.icons.MENU_SHARP, color=ft.colors.BLACK)
        self.yes_icon       = ft.Icon(name=ft.icons.CHECK_CIRCLE, color=ft.colors.WHITE)
        self.no_icon        = ft.Icon(name=ft.icons.NOT_INTERESTED, color=ft.colors.WHITE)
        self.skip_icon      = ft.Icon(name=ft.icons.SKIP_NEXT, color=ft.colors.BLACK)
        self.plus_icon      = ft.Icon(name=ft.icons.ADD, color=ft.colors.BLACK)
        self.edit_icon      = ft.Icon(name=ft.icons.EDIT, color=ft.colors.BLACK)
        ############################################################
        # Define UI components
        #   Home Page has 7 total "buttons"
        #   Home Page has 10 Components that get displayed (including the 7 buttons)
        self.menu_button                    = ft.ElevatedButton(
            content=self.menu_icon, 
            bgcolor="white", 
            on_click=self.go_to_menu_page)

        self.add_new_question_button        = ft.IconButton(
            icon        = ft.icons.ADD,
            icon_color  = ft.colors.BLACK,
            tooltip     = "Add A New Question",
            bgcolor     = ft.colors.WHITE,
            on_click=self.go_to_add_question_page
            )

        self.edit_current_question_button   = ft.IconButton(
            icon        = ft.icons.EDIT,
            icon_color  = ft.colors.BLACK,
            tooltip     = "Edit the current question",
            bgcolor     = ft.colors.WHITE,
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
        self.image_object          = ft.Image(src=f"system_data/media_files/", width=300)
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
            expand      =   True,
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
            ink_color=ft.colors.GREY_500,
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
            value=str(f"Rem: {len(self.user_profile_data['questions']['in_circulation_is_eligible'])}"),
            tooltip="The amount of questions remaining to be answered,\n When this value hits zero, Quizzer will determine if it will put more questions in front of you."
        )
        self.total_answered_today = ft.Text(
            value=str(f"TAT:{self.user_profile_data['stats']['questions_answered_by_date'][self.todays_date]}"),
            tooltip="This number represents the amount of questions you've answered just for today"
        )
        self.first_row = ft.Row(
            alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
            controls=[
                self.menu_button,
                self.remaining_questions_counter,
                self.total_answered_today,
                self.row_one # contains add and edit question button
            ],
            height=50
        )
        self.middle_row = ft.Row(
            alignment=ft.MainAxisAlignment.CENTER,
            controls=[
                self.question_object_display_button
            ],
            wrap=True
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

        self.column_one = ft.Column(
            expand=True,
            alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
            controls=[
                self.first_row,
                self.middle_row,
                self.bottom_row
            ]
        )

        ############################################################
        # Piece it all together with self.controls
        self.controls=[
            self.column_one
        ]
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
        self.get_next_question()
        self.user_profile_data["questions"] = system_data.sort_questions(self.user_profile_data, self.question_object_data)
        self.user_profile_data = system_data.update_circulating_non_eligible_questions(
            self.user_profile_data,
            self.question_object_data
        )        
        if self.questions_available_to_answer == False:
            return None
        # Execute these if there are available questions
        self.currently_displayed == "question"
        self.text_object.value  = self.current_question["question_text"]
        self.text_object.size   = 16
        self.image_object.src   = f"system_data/media_files/{self.current_question['question_image']}"
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
            self.user_profile_data = system_data.update_circulating_non_eligible_questions(
                self.user_profile_data,
                self.question_object_data
            )
            # Go through the reserve bank and see if we can put anything into circulation
            self.user_profile_data = generate_quiz.update_questions_in_circulation(
                self.user_profile_data,
                self.question_object_data
            )
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
        print(f"def get_next_question()")
        # If the question list has no questions in it, attempt to fill it again
        self.verify_if_remaining_questions()
        if self.questions_available_to_answer == True:
            self.current_question_id = random.choice(list(self.user_profile_data["questions"]["in_circulation_is_eligible"].keys()))
            self.current_question    = self.question_object_data[self.current_question_id].copy()
        self.page.update()

    def question_answered(self, e: ft.ControlEvent, status):
        '''
        Calls backend update_score function with status of correct
        '''
        print(f"def question_answered(e: ft.ControlEvent, status: int) -> None")
        self.correct_button.disabled    = True
        self.incorrect_button.disabled  = True
        self.page.update()
        print(f"    Updating question <{self.current_question_id}> with status of <{status}>")
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
        system_data.update_user_profile(self.user_profile_data)
        self.verify_if_remaining_questions()
        # Refresh stats when a question is answered
        self.remaining_questions_counter.value  = str(f"Rem: {len(self.user_profile_data['questions']['in_circulation_is_eligible'])}")
        self.total_answered_today.value         = str(f"TAT:{self.user_profile_data['stats']['questions_answered_by_date'][self.todays_date]}")
        self.page.update()


        


    def skip_to_next_question(self, e: ft.ControlEvent):
        '''
        Skips to next question, does not update any statistics on the backend
        '''
        print(f"def skip_to_next_question(e: ft.ControlEvent)")
        print("    Skipping question")
        # Disable the button while it processes
        self.skip_button.disabled=True
        self.page.update()
        self.get_next_question()
        if self.questions_available_to_answer == True:
            self.text_object.value          = self.current_question["question_text"]
            self.image_object.src           = f"system_data/media_files/{self.current_question['question_image']}"
        self.currently_displayed        = "question"
        self.has_seen = False
        self.skip_button.disabled=False
        self.page.update()

    def flip_question_answer(self, e):
        print("def flip_question_answer(self, e)")
        print("Current Question ID:", self.current_question_id)
        self.verify_if_remaining_questions()
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