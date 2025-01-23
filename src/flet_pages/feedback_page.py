import flet as ft
import system_data
import firestore_db
import time

class FeedbackPage(ft.View):
    def __init__(self, page: ft.Page, pages_visited) -> None:
        super().__init__()
        # CONSTRUCT THE PAGE
        # Assign passed globals to instance
        self.page               = page
        self.page.theme_mode    = ft.ThemeMode.DARK
        self.pages_visited      = pages_visited
        self.scroll             = ft.ScrollMode.ALWAYS
        ############################################################
        # Define General Data

        ############################################################
        # Define Icons
        self.menu_icon      = ft.Icon(
            name    = ft.Icons.MENU_SHARP, 
            color   = ft.Colors.BLACK)
        self.buy_me_a_coffee_image = ft.Image(src="system_data/non_question_assets/support_me.webp",
                                              width = 300)        
        ############################################################
        # Define Simple UI components
        self.message_to_user = ft.Text(value="Thanks for Downloading Quizzer!\n\n I assume you're here to give feedback, maybe a bug, or a suggestion for a new feature. I look forward to hearing back. So long as you have an internet connection I'll be able to read whatever it is you submit. And if you're really enjoying the experience or would just like to help fund further development, I'd be grateful if you would donate using the Buy Me A Coffee link down below.\n\n The aim of quizzer is to simplify and enhance the learning process, so certain features like building 'decks' or similar things that support cramming are just not intended functionality. Learning is lifelong endevour and quizzer is your companion on that endevour. So while I understand that you might be looking to just cram for that next test I'd highly encourage you to adopt a system that will help you retain what you've learned over the long term, not just long enough to pass that exam.",
                                       size = 16)
        self.categorize_menu    = ft.Dropdown(
            label       = "Type of Feedback",
            hint_text   = "Is this a Bug Report, A Feature, or something else?",
            options     = [
                ft.dropdown.Option("Bug Report"),
                ft.dropdown.Option("Feature Suggestion"),
                ft.dropdown.Option("Something Else")
            ]
        )
        self.feedback_box       = ft.TextField(
            label       = "What are you thinking?",
            multiline   = True
        )
        self.donation_link      = ft.Container(
            content=self.buy_me_a_coffee_image,
            ink             = True,
            ink_color       = ft.Colors.GREY_500,
            bgcolor         = ft.Colors.GREEN,
            border_radius   = 50,
            on_click        = self.open_link
        )
        # Components with functions
        self.menu_button                    = ft.ElevatedButton(
            content=self.menu_icon, 
            bgcolor="white", 
            on_click=self.go_to_menu_page)
        self.exit_button                    = ft.IconButton(
            icon=ft.Icons.ARROW_BACK,
            icon_color=ft.Colors.BLACK,
            bgcolor=ft.Colors.WHITE,
            on_click=self.go_to_home_screen
        )
        self.submit_button                  = ft.ElevatedButton(
            text        = "Submit Feedback",
            on_click    = self.submit_feedback
        ) 
        ############################################################
        # Define Composite Components -> ft.Container buttons

        ############################################################
        # Define Container elements for organization
        self.header_row = ft.Row(
            alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
            controls=[
                self.menu_button,
                ft.Text(value="Give Feedback!", size=25),
                self.exit_button
            ]
        )
        ############################################################
        # Piece it all together with self.controls
        self.controls=[
            self.header_row,
            self.message_to_user,
            self.categorize_menu,
            self.feedback_box,
            self.submit_button,
            ft.Row(alignment=ft.MainAxisAlignment.CENTER, controls=[self.donation_link])
        ]
    # Page Functionality below:
    # Navigation Functions Built In
    def open_link(self, e = None):
        self.page.launch_url("https://buymeacoffee.com/quizer")

    def submit_feedback(self, e: ft.ControlEvent):
        print(self.categorize_menu.value)
        print(self.feedback_box.value)
        self.submit_button.text     = "THANKS!"
        self.submit_button.disabled = True
        self.page.update()
        time.sleep(1)
        self.submit_button.disabled = False
        category = self.categorize_menu.value
        feedback = self.feedback_box.value
        firestore_db.submit_feedback_to_firestore(category, feedback)
        self.categorize_menu.value = "Is this a Bug Report, A Feature, or something else?"
        self.feedback_box.value    = "Anything Else?"
        self.page.update()
    def go_to_new_profile_screen            (self, e: ft.ControlEvent = None):
        self.page.go("/NewProfilePage")

    def go_to_home_screen                   (self, e: ft.ControlEvent = None):
        self.page.go("/HomePage")

    def go_to_login_page                    (self, e: ft.ControlEvent = None):
        self.page.go("/LoginPage")

    def go_to_menu_page                     (self, e: ft.ControlEvent = None):
        self.page.go("/Menu")

    def go_to_add_question_page             (self, e: ft.ControlEvent = None):
        self.page.go("/AddQuestionPage")

    def go_to_edit_question_page            (self, e: ft.ControlEvent = None):
        self.page.go("/EditQuestionPage")

    def go_to_settings_page                 (self, e: ft.ControlEvent = None):
        self.page.go("/SettingPage")

    def go_to_stats_page                    (self, e: ft.ControlEvent = None):
        self.page.go("/StatsPage")

    def go_to_user_profile_page             (self, e: ft.ControlEvent = None):
        self.page.go("/UserProfilePage")

    def go_to_display_modules_page             (self, e: ft.ControlEvent = None):
        self.page.go("/DisplayModulePage")
    
    def go_to_ai_question_generator_page    (self, e: ft.ControlEvent = None):
        self.page.go("/AIQuestionGeneratorPage")