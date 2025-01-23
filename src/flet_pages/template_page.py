import flet as ft
import system_data

class NewPage(ft.View):
    def __init__(self, page: ft.Page, questions_list, questions_available_to_answer, 
                 current_question,current_question_id,question_object_data,
                 user_profile_data,CURRENT_USER,CURRENT_UUID) -> None:
        super().__init__()
        # CONSTRUCT THE PAGE
        # Assign passed globals to instance

        ############################################################
        # Define General Data

        ############################################################
        # Define Icons
        self.menu_icon      = ft.Icon(
            name    = ft.Icons.MENU_SHARP, 
            color   = ft.Colors.BLACK)        
        ############################################################
        # Define Simple UI components

        # Components with functions
        self.menu_button                    = ft.ElevatedButton(
            content=self.menu_icon, 
            bgcolor="white", 
            on_click=self.go_to_menu_page)
        
        self.exit_button                            = ft.IconButton(
            icon=ft.Icons.ARROW_BACK,
            icon_color=ft.Colors.BLACK,
            bgcolor=ft.Colors.WHITE,
            on_click=self.go_to_home_screen
        )                
        ############################################################
        # Define Composite Components -> ft.Container buttons

        ############################################################
        # Define Container elements for organization
        self.header_row                     = ft.Row(
            alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
            controls=[
                self.menu_button,
                ft.Text(value = "Template Page", size=24),
                self.exit_button
            ]
        )


        ############################################################
        # Piece it all together with self.controls
        self.controls=[self.header_row]


    # Page Functionality below:
    # Navigation Functions Built In
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