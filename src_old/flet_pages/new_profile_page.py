import flet as ft
import system_data
import firestore_db

class NewProfilePage(ft.View):
    def __init__(self, page: ft.Page, question_object_data) -> None:
        super().__init__()
        # CONSTRUCT THE PAGE
        # Assign passed globals to instance
        self.question_object_data = question_object_data
        ############################################################
        # Define General Data
        self.page                = page
        self.page.theme_mode     = ft.ThemeMode.DARK
        self.page.title          = "Quizzer - New Profile Entry"
        self.email_submission    = ""
        self.password_submission = ""
        ############################################################
        # Define UI components
        self.email_entry                = ft.TextField(
            label               = "Login with Email",
            text_align          = "center",
            on_change           = self.update_email_submission
        )
        self.password_entry             = ft.TextField(
            label               = "Enter your password",
            text_align          = "center",
            password            = True,
            can_reveal_password = True,
            on_change           = self.update_password_submission
        )

        # Components with functions
        self.submit_new_user_button = ft.ElevatedButton(
            text="Submit", 
            on_click=lambda e: self.generate_user_profile(
                e), 
            visible=True)
        

        self.cancel_new_user_button = ft.ElevatedButton(
            text="Cancel", 
            on_click=self.go_to_login_page, 
            visible=True)     

        ############################################################
        # Piece it all together with self.controls
        self.controls=[
            ft.Row(
                controls  =[self.email_entry],
                alignment = ft.MainAxisAlignment.CENTER
            ),
            ft.Row(
                controls  =[self.password_entry],
                alignment = ft.MainAxisAlignment.CENTER
            ),
            ft.Row(
                controls  =[self.submit_new_user_button, self.cancel_new_user_button],
                alignment = ft.MainAxisAlignment.CENTER
            )
        ]
        self.horizontal_alignment = ft.MainAxisAlignment.CENTER
        self.vertical_alignment   = ft.MainAxisAlignment.CENTER

    # Page Functionality below:
    def go_to_login_page(self, e: ft.ControlEvent = None):
        self.page.go("/LoginPage")
    
    def generate_user_profile(self, e):
        try:
            print(self.email_submission)
            system_data.add_new_user(self.email_submission, self.question_object_data)
            self.create_user()
            self.go_to_login_page()
        except Exception as e:
            print("Invalid Entry")
            print(e)
    def create_user(self, e = None):
        firestore_db.create_user(self.email_submission, self.password_submission)
    def update_email_submission(self, e):
        self.email_submission = e.data
        print(self.email_submission)

    def update_password_submission(self, e):
        self.password_submission = e.data
        print(self.password_submission)