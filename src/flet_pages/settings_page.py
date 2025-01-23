import flet as ft
from flet_custom_containers import settings_controls
import system_data

class SettingsPage(ft.View):
    def __init__(self, page: ft.Page, questions_available_to_answer, 
                 current_question,current_question_id,question_object_data,
                 user_profile_data,CURRENT_USER,CURRENT_UUID) -> None:
        super().__init__()
        self.page                           = page
        self.page.theme_mode                = ft.ThemeMode.DARK
        self.questions_available_to_answer  = questions_available_to_answer
        self.user_profile_data              = user_profile_data
        self.current_question               = current_question
        self.current_question_id            = current_question_id
        self.question_object_data           = question_object_data
        self.CURRENT_USER                   = CURRENT_USER
        self.CURRENT_UUID                   = CURRENT_UUID

        self.page.title                     = "Settings Page"
        self.subject_list                   = list(self.user_profile_data["settings"]["subject_settings"].keys())
        self.subject_list.sort()
        print(self.subject_list)
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

        self.time_between_revisions_card    = settings_controls.IntegerSettingCard("time_between_revisions", 
                                                                                   self.user_profile_data["settings"]["time_between_revisions"],
                                                                                   self.user_profile_data
                                                                                   )
        self.desired_daily_questions_card   = settings_controls.IntegerSettingCard("desired_daily_questions",
                                                                                   self.user_profile_data["settings"]["desired_daily_questions"],
                                                                                   self.user_profile_data                                                                                   
                                                                                   )
        self.due_date_sensitivity_card      = settings_controls.IntegerSettingCard("due_date_sensitivity",
                                                                                   self.user_profile_data["settings"]["due_date_sensitivity"],
                                                                                   self.user_profile_data
                                                                                   )
        self.is_module_active_by_default_card=settings_controls.BooleanSettingCard("is_module_active_by_default",
                                                                                   self.user_profile_data["settings"]["module_settings"]["is_module_active_by_default"],
                                                                                   self.user_profile_data)
        
        self.header_bar                     = ft.Row(
            controls=[
                self.menu_button,
                ft.Text(value="Settings", size=24),
                self.exit_button
            ],
            alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
            width = 400
        )

        self.subject_setting_header         = ft.Row(
            width       = 400,
            controls    =[
                ft.Text(
                    value   = "Subject Name",
                    width   = 200,
                    tooltip = "The Name of the Subject whose setting you're changing"
                ),
                ft.Text(
                    value   = "Interest Level",
                    width   = 100,
                    tooltip = "On a Scale of 0 - 100, how interested are you in this subject? Set 0 to disable questions of this subject, Quizzer uses this value to determine the ratio of questions shown based on YOUR level of interest in each subject"
                ),
                ft.Text(
                    value   = "Priority Level",
                    width   = 100,
                    tooltip = "Give an integer value, A value of 1 marks highest priority, a value of 9 or higher marks low priority. Quizzer uses this value to determine which subjects will get questions added before others"
                )
            ]
        )
        self.subject_setting_cards          = ft.Column(
            controls= [],
            width   = 400,
            scroll  = ft.ScrollMode.ALWAYS
        )

        ############################################################
        # Piece it all together with self.controls
        self.controls=[
            self.header_bar,
            ft.Text(value="General Settings", size = 16),
            self.time_between_revisions_card,
            self.desired_daily_questions_card,
            self.due_date_sensitivity_card,
            self.is_module_active_by_default_card,
            self.subject_setting_header
        ]
        for subject_name in self.subject_list:
            self.controls.append(settings_controls.SubjectSettingCard(subject_name,self.user_profile_data))
        self.scroll = ft.ScrollMode.ALWAYS


    # Page Functionality below:
    # Navigation Functions Built In
    def add_settings_cards                  (self, e: ft.ControlEvent = None):
        pass
    def go_to_home_screen                   (self, e: ft.ControlEvent = None):
        system_data.update_user_profile(self.user_profile_data)
        self.page.go("/HomePage")

    def go_to_menu_page                     (self, e: ft.ControlEvent = None):
        system_data.update_user_profile(self.user_profile_data)
        self.page.go("/Menu")