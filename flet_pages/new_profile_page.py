import flet as ft
import system_data

class NewProfilePage(ft.View):
    def __init__(self, page: ft.Page, question_object_data) -> None:
        super().__init__()
        # CONSTRUCT THE PAGE
        # Assign passed globals to instance
        self.question_object_data = question_object_data
        ############################################################
        # Define General Data
        self.page = page
        self.page.title = "Quizzer - New Profile Entry"
        ############################################################
        # Define UI components
        #   NewProfilePage has 3 buttons
        self.user_name_field = ft.TextField(
            label="User Name", 
            width=250,
            visible=True)


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
        # Define Container elements for organization
        #   NewProfilePage has two rows
        #   NewProfilePage groups those rows into a single container
        self.row_one = ft.Row(
            alignment=ft.MainAxisAlignment.CENTER,
            controls=[self.user_name_field])
        self.row_two = ft.Row(
            alignment=ft.MainAxisAlignment.CENTER,
            controls=[self.submit_new_user_button,self.cancel_new_user_button]
        )
        self.centered_box = ft.Column(
            alignment=ft.MainAxisAlignment.CENTER,
            expand=True,
            spacing=25,
            controls=[self.row_one,self.row_two]
        )

        ############################################################
        # Piece it all together with self.controls
        self.controls=[self.centered_box]

    # Page Functionality below:
    def go_to_login_page(self, e: ft.ControlEvent = None):
        self.page.go("/LoginPage")
    
    def generate_user_profile(self, e):
        print(self.user_name_field.value)
        system_data.add_new_user(self.user_name_field.value, self.question_object_data)
        self.go_to_login_page()