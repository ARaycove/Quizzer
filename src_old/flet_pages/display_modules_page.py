import flet as ft
import system_data
from flet_custom_containers import custom_controls

class DisplayModulePage(ft.View):
    def __init__(self, page: ft.Page,user_profile_data,all_module_data:dict,question_object_data) -> None:
        super().__init__()
        # CONSTRUCT THE PAGE
        # Assign passed globals to instance
        self.page                   = page
        self.page.theme_mode        = ft.ThemeMode.DARK
        self.user_profile_data      = user_profile_data
        self.all_module_data        = all_module_data
        self.question_object_data   = question_object_data
        ############################################################
        # Define General Data
        self.module_list    = all_module_data.keys()
        self.card_list      = []
        for module_name in self.module_list:
            self.card_list.append(
                ft.Container(
                    content=custom_controls.module_card(module_name, self.user_profile_data, self.all_module_data, self.question_object_data),
                    padding=30,
                    bgcolor=ft.Colors.GREY,
                    border_radius=15
                    ))
        ############################################################
        # Define Icons
        self.menu_icon      = ft.Icon(
            name    = ft.Icons.MENU_SHARP, 
            color   = ft.Colors.BLACK)        
        ############################################################
        # Define Simple UI components
        # A Column of module cards, each card shows details about that module
        self.module_column                  = ft.Column(
            controls=self.card_list,
            spacing=10,
            scroll=ft.ScrollMode.ALWAYS
        )
        # self.container
        # Components with functions
        self.menu_button                    = ft.ElevatedButton(
            content=self.menu_icon, 
            bgcolor="white", 
            on_click=self.go_to_menu_page)
                
        ############################################################
        # Define Composite Components -> ft.Container buttons

        ############################################################
        # Define Container elements for organization
        self.page_header                    = ft.Row(
            controls=[
                self.menu_button,
                ft.Text(value="All Modules", size=24),
                ft.IconButton(
                    icon=ft.Icons.SORT,
                    icon_color=ft.Colors.BLACK,
                    bgcolor=ft.Colors.WHITE
                )
            ],
            alignment=ft.MainAxisAlignment.SPACE_BETWEEN
        )


        ############################################################
        # Piece it all together with self.controls
        self.controls=[
            self.page_header,
            self.module_column]
        self.scroll = ft.ScrollMode.ALWAYS


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