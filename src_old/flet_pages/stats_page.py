import flet as ft
import system_data
import time
from flet_custom_containers import stat_cards

class StatsPage(ft.View):
    def __init__(self, page: ft.Page,
                 user_profile_data,
                 CURRENT_USER,
                 CURRENT_UUID) -> None:
        super().__init__()
        # CONSTRUCT THE PAGE
        # Assign passed globals to instance
        self.page               = page
        self.user_profile_data  = user_profile_data
        self.CURRENT_USER       = CURRENT_USER
        self.CURRENT_UUID       = CURRENT_UUID

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
                ft.Text(value = "Stats", size=24),
                self.exit_button
            ]
        )

        self.total_answered_card            = stat_cards.IntegerStat("total_questions_answered",
                                                                     self.user_profile_data["stats"]["total_questions_answered"],
                                                                     self.user_profile_data)
        self.average_shown                  = stat_cards.IntegerStat("average_questions_per_day",
                                                                     self.user_profile_data["stats"]["average_questions_per_day"],
                                                                     self.user_profile_data)
        self.current_in_circ                = stat_cards.IntegerStat("current_questions_in_circulation",
                                                                     self.user_profile_data["stats"]["current_questions_in_circulation"],
                                                                     self.user_profile_data)
        self.new_questions_daily            = stat_cards.IntegerStat("average_num_questions_entering_circulation_daily",
                                                                     self.user_profile_data["stats"]["average_num_questions_entering_circulation_daily"],
                                                                     self.user_profile_data)
        self.non_circulating_questions      = stat_cards.IntegerStat("non_circulating_questions",
                                                                     self.user_profile_data["stats"]["non_circulating_questions"],
                                                                     self.user_profile_data)
        self.days_to_exhaust                = stat_cards.IntegerStat("reserve_questions_exhaust_in_x_days",
                                                                     self.user_profile_data["stats"]["reserve_questions_exhaust_in_x_days"],
                                                                     self.user_profile_data)
        self.simple_stats_column            = ft.Column(
            controls=[
                self.total_answered_card,
                self.average_shown,
                self.current_in_circ,
                self.new_questions_daily,
                self.non_circulating_questions,
                self.days_to_exhaust
            ]
        )
        self.questions_over_time_graph      = ft.Image(src="system_data/non_question_assets/questions_answered_with_target.png",
                                                       width=self.page.window.width)
        ############################################################
        # Piece it all together with self.controls
        self.controls=[self.header_row,
                       self.simple_stats_column,
                       self.questions_over_time_graph]

        self.rebuild()

    def rebuild(self):
        self.questions_over_time_graph      = ft.Image(src="system_data/non_question_assets/questions_answered_with_target.png",
                                                width=self.page.window.width)

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