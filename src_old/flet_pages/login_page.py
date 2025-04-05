import flet as ft
import system_data
import generate_quiz
import firestore_db
import requests

class LoginPage(ft.View):
    def __init__(self, page: ft.Page, questions_available_to_answer, 
                 question_object_data,
                 user_profile_data,CURRENT_USER,CURRENT_UUID,pages_visited
                 ) -> None:
        super().__init__()
        # Assign passed globals to instance
        self.questions_available_to_answer  = questions_available_to_answer
        self.question_object_data           = question_object_data
        self.user_profile_data              = user_profile_data
        self.CURRENT_USER                   = CURRENT_USER
        self.CURRENT_UUID                   = CURRENT_UUID
        self.pages_visited                  = pages_visited
        ############################################################
        # Define General Data
        self.page                   = page
        self.page.title             = "Quizzer - LoginPage"
        self.page.theme_mode        = ft.ThemeMode.DARK
        self.current_user_list      = system_data.get_user_list()
        self.email_submission       = ""
        self.password_submission    = ""
        ############################################################
        # Define Container elements for organization
        # We will have three rows in which buttons are placed
        # self.page.window.width = 400
        self.quizzer_image     = ft.Image(
            src = "system_data/non_question_assets/Quizzer_Logo.png",
            height = 300,
            expand=True
        )
        self.center_image       = ft.Row(
            controls=[self.quizzer_image],
            alignment=ft.MainAxisAlignment.CENTER,
        )
        self.email_entry                = ft.TextField(
            label       = "Login with Email",
            text_align  = "center",
            on_change   = self.update_email_submission
        )
        self.password_entry             = ft.TextField(
            label               = "Enter your password",
            text_align          = "center",
            password            = True,
            can_reveal_password = True,
            on_change           = self.update_password_submission
        )
        self.create_new_user_button     = ft.ElevatedButton(
            text        = "NEW USER",
            on_click    = self.go_to_new_profile_screen,
            width       = 150
        )
        self.submit_button              = ft.ElevatedButton(
            text        = "CONTINUE",
            on_click    = lambda e: self.initialize_program(e, self.email_submission),
            width       = 150
        )
        self.manual_login_col           = ft.Column(
            controls    = [
                self.email_entry,
                self.password_entry,
                ft.Row(
                    controls=[self.create_new_user_button,self.submit_button],
                    width = 300,
                    alignment= ft.MainAxisAlignment.SPACE_BETWEEN
                )
            ],
            horizontal_alignment        = ft.CrossAxisAlignment.CENTER
        )
        self.google_login_content       = ft.Row(
            controls=[
                ft.Image(src="system_data/non_question_assets/google_logo.png", height=50, color_blend_mode=ft.BlendMode.MULTIPLY),
                ft.Text(value="Login with Google")
            ]
        )
        self.login_with_google_button   = ft. ElevatedButton(
            on_click    = lambda e: print(e), #FIXME
            content     = self.google_login_content,
            bgcolor     = ft.Colors.WHITE,
            color       = ft.Colors.BLACK
        )

        self.centered_box = ft.Column(alignment=ft.MainAxisAlignment.START,
                                      expand=True,
                                      spacing=25,
                                      controls=[self.center_image,
                                                self.manual_login_col,
                                                ft.Row(controls=[ft.Text(value="OR")], alignment=ft.MainAxisAlignment.CENTER),
                                                self.login_with_google_button
                                                ])
        ############################################################
        # Piece it all together with self.controls
        self.controls=[self.centered_box]
    


    def initialize_program(self, e: ft.ControlEvent, user_name: str):
        try:
            self.status_code = 200
            # self.status_code = self.authenticate_call()
        except requests.exceptions.SSLError as e:
            print(f"No internet, {e}")
            self.email_entry.value = "Please Connect to the Internet"
            self.page.update()
            return None
        print(self.status_code)
        if self.status_code != 200:
            return None
        self.email_entry.value = "SUCCESS, Please Wait while Quizzer gets your data"
        self.password_entry.value = "This Might Take a While"
        self.password_entry.password = False
        self.submit_button.disabled = True
        self.create_new_user_button.disabled = True
        self.page.update()
        self.CURRENT_USER = user_name
        print(self.CURRENT_USER)

        # Sync Data then assign globals
        # try:
        #     system_data.sync_local_data_with_cloud_data(self.CURRENT_USER)
        # except requests.exceptions.ConnectionError as e:
        #     print("No Internet Connection, can't sync with cloud storage")
        self.question_object_data = system_data.get_question_object_data()
        self.user_profile_data    = system_data.get_user_data(self.CURRENT_USER)
        self.CURRENT_UUID = self.user_profile_data["uuid"]

        print(f"Current User: <{self.CURRENT_USER}> WITH UUID: <{self.CURRENT_UUID}>")
        # Sort any unsorted questions that may be in the user_profile
        self.user_profile_data["questions"] = system_data.sort_questions(self.user_profile_data, self.question_object_data)
        system_data.update_user_profile(self.user_profile_data)
        print("These Keys:", self.user_profile_data.keys())
        self.go_to_home_screen()

    def update_email_submission(self, e):
        self.email_submission = e.data
        print(self.email_submission)

    def update_password_submission(self, e):
        self.password_submission = e.data
        print(self.password_submission)

    def authenticate_call(self, e = None):
        response = firestore_db.authenticate(self.email_submission, self.password_submission)
        return response
        # Send verification email
        # user.send_email_verification()go_to_login_page()
    def go_to_new_profile_screen(self, e):
        self.page.go("/NewProfilePage")

    def go_to_home_screen(self):
        self.page.go("/HomePage")


    # Define organizational containers
   


    # # Define properties of the login page
    # @property
    # def name()

        