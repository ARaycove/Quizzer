import flet as ft
import system_data

class MenuPage(ft.View):
    def __init__(self, page: ft.Page, pages_visited) -> None:
        super().__init__()
        # CONSTRUCT THE PAGE
        # Assign passed globals to instance
        self.page = page
        self.pages_visited = pages_visited
        ############################################################
        # Define General Data

        ############################################################
        # Define Icons
        self.under_construction_icon    = ft.Icon(
            name    = ft.icons.CONSTRUCTION,
            color   = ft.colors.WHITE)
        
        self.logout_icon                = ft.Icon(
            name    = ft.icons.LOGOUT, 
            color   = ft.colors.WHITE)
        
        self.settings_icon = ft.Icon(
            name    = ft.icons.SETTINGS, 
            color   = ft.colors.WHITE)
        
        self.stats_icon = ft.Icon(
            name    = ft.icons.QUERY_STATS, 
            color   = ft.colors.WHITE)
        
        self.display_modules_icon = ft.Icon(
            name    = ft.icons.LAPTOP_CHROMEBOOK, 
            color   = ft.colors.WHITE)
        
        self.user_profile_icon = ft.Icon(
            name    = ft.icons.ACCOUNT_CIRCLE, 
            color   = ft.colors.WHITE)
        
        self.ai_question_object_gen_icon = ft.Icon(
            name    = ft.icons.SCIENCE, 
            color   = ft.colors.WHITE)
        
        self.menu_icon      = ft.Icon(
            name    = ft.icons.MENU_SHARP, 
            color   = ft.colors.BLACK)
        ############################################################
        # Define Simple UI components
        self.logout_text                    = ft.Text(value="LOGOUT")
        self.settings_text                  = ft.Text(value="SETTINGS")
        self.stats_text                     = ft.Text(value="STATS")
        self.display_modules_text            = ft.Text(value="DISPLAY MODULES")
        self.user_profile_text              = ft.Text(value="MY PROFILE")
        self.ai_question_object_gen_text    = ft.Text(value="AI Question Maker")
        # Components with functions
        self.menu_button                    = ft.ElevatedButton(
            content=self.menu_icon, 
            bgcolor="white", 
            on_click=self.go_to_last_visited_page)      
        ############################################################
        # Define Composite Components -> ft.Container buttons
        self.logout_row                     = ft.Row(
            controls=[
                self.logout_icon, 
                self.logout_text])
        self.logout_button                  = ft.ElevatedButton(
            content     =self.logout_row, 
            on_click    =self.go_to_login_page)
        

        self.settings_row                   = ft.Row(
            controls=[
                self.settings_icon,
                self.settings_text])
        self.settings_button                = ft.ElevatedButton(
            content     =self.settings_row, 
            on_click    =self.go_to_settings_page,
            disabled=True)


        self.stats_row                      = ft.Row(
            controls=[
                self.stats_icon,
                self.stats_text,
                self.under_construction_icon])
        self.stats_button                   = ft.ElevatedButton(
            content=self.stats_row, 
            disabled=True)
        
        self.display_modules_row             = ft.Row(
            controls=[
                self.display_modules_icon,
                self.display_modules_text
            ]
        )
        self.display_modules_button         = ft.ElevatedButton(
            content=self.display_modules_row,
            on_click=self.go_to_display_modules_page
        )

        self.user_profile_row = ft.Row(
            controls=[
                self.user_profile_icon,
                self.user_profile_text,
                self.under_construction_icon])
        self.user_profile_button = ft.ElevatedButton(
            content=self.user_profile_row, 
            disabled=True)
        
        self.ai_question_object_gen_row = ft.Row(
            controls=[
                self.ai_question_object_gen_icon,
                self.ai_question_object_gen_text,
                self.under_construction_icon])
        self.ai_question_object_gen_button = ft.ElevatedButton(
            content=self.ai_question_object_gen_row, 
            disabled=True)
        ############################################################
        # Define Container elements for organization
        self.menu_column = ft.Column(
            controls=[
                ft.Row(controls=[
                    self.menu_button,
                    ft.IconButton(
                        icon        = ft.icons.HOME,
                        icon_color  = ft.colors.BLACK,
                        bgcolor     = ft.colors.WHITE,
                        on_click    = self.go_to_home_screen
                    )]),
                self.display_modules_button,
                self.ai_question_object_gen_button,
                self.settings_button,
                self.stats_button,
                self.user_profile_button,
                self.logout_button],
            alignment=ft.MainAxisAlignment.START,
            horizontal_alignment=ft.MainAxisAlignment.START)
        ############################################################
        # Piece it all together with self.controls
        self.controls=[self.menu_column]

    # Page Functionality below:
    # Navigation Functions Built In
    def go_to_last_visited_page(self, e: ft.ControlEvent = None):
        self.page.go(self.pages_visited[-2]) # -1 index is the last page in the list which is always the current page displayed'
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