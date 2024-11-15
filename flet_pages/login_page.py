import flet as ft
import system_data
import generate_quiz

class LoginPage(ft.View):
    def __init__(self, page: ft.Page, questions_available_to_answer, 
                 question_object_data,
                 user_profile_data,CURRENT_USER,CURRENT_UUID,pages_visited) -> None:
        super().__init__()
        # Assign passed globals to instance
        self.questions_available_to_answer = questions_available_to_answer
        self.question_object_data = question_object_data
        self.user_profile_data = user_profile_data
        self.CURRENT_USER = CURRENT_USER
        self.CURRENT_UUID = CURRENT_UUID
        self.pages_visited = pages_visited
        ############################################################
        # Define General Data
        self.page = page
        self.page.title = "Quizzer - LoginPage"
        self.current_user_list = system_data.get_user_list()
        ############################################################
        # Define UI components
        #   Login page has four buttons
        self.user_name_dropdown_select = ft.Dropdown(
            visible=True,
            label="User Name",
            width=250,
            options=[ft.dropdown.Option(i) for i in self.current_user_list])
        self.password_field = ft.TextField(
            label="Password", 
            value="Not Implemented Yet", 
            width=250, 
            disabled=True)
        # Components with functions
        self.add_new_user_button = ft.ElevatedButton(
            text="Add New User", 
            on_click=self.go_to_new_profile_screen, 
            visible=True)
        self.submit_login = ft.ElevatedButton(
            text="Login", 
            visible=True,
            on_click=lambda e: self.initialize_program(e, self.user_name_dropdown_select.value)
            )

        ############################################################
        # Define Container elements for organization
        # We will have three rows in which buttons are placed
        self.row_one   = ft.Row(alignment=ft.MainAxisAlignment.CENTER,
                                controls=[self.user_name_dropdown_select])
        self.row_two   = ft.Row(alignment=ft.MainAxisAlignment.CENTER,
                                controls=[self.password_field])
        self.row_three = ft.Row(alignment=ft.MainAxisAlignment.CENTER,
                                controls=[self.add_new_user_button,self.submit_login]) 

        self.centered_box = ft.Column(alignment=ft.MainAxisAlignment.CENTER,
                                      expand=True,
                                      spacing=25,
                                      controls=[self.row_one,self.row_two,self.row_three])
        ############################################################
        # Piece it all together with self.controls
        self.controls=[self.centered_box]
    
    def go_to_new_profile_screen(self, e):
        self.page.go("/NewProfilePage")

    def go_to_home_screen(self):
        self.page.go("/HomePage")
        
    def go_to_display_modules_page             (self, e: ft.ControlEvent = None):
        self.page.go("/DisplayModulePage")

    def initialize_program(self, e: ft.ControlEvent, user_name: str):
        # Assign Globals with system data
        self.user_profile_data = system_data.get_user_data(user_name)
        self.CURRENT_USER = self.user_profile_data["user_name"]
        self.CURRENT_UUID = self.user_profile_data["uuid"]
        print(f"Current User: <{self.CURRENT_USER}> WITH UUID: <{self.CURRENT_UUID}>")
        # Sort any unsorted questions that may be in the user_profile
        self.user_profile_data["questions"] = system_data.sort_questions(self.user_profile_data, self.question_object_data)
        system_data.update_user_profile(self.user_profile_data)
        self.go_to_home_screen()

    


    
    

    # Define organizational containers

    


    # # Define properties of the login page
    # @property
    # def name()

        