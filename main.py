import flet as ft
from lib import helper
from datetime import date
import system_data
import generate_quiz
import public_functions

# FUTURE PLANS AND IMPLEMENTATIONS:
#FIXME, future code (when connecting to the main server) user profiles on the user system will need to be registered to the Quizzer account, otherwise the user
# may remain offline without any online features. Similar to many mobile games out there, account registration optional

#################
# Roadmap
#PRIORITY 1:
# - Create Menu Page #FIXME
# -- List of other pages belonging to the user

# - Return to Login screen button #FIXME
# -- Logout button that returns the user to the login screen to select a different profile

# - Create stats Page #FIXME
# -- Visual Feed of all data collected in regards to the user's performance

# - Settings Page #FIXME
# -- Allow the user to update any and all settings, Frontend allows us to prevent invalid input (That's great!)

# - Display Modules Page #FIXME
# -- Display a list of all modules downloaded into the users local system,
# -- Could use these AI modules to generate a cover image based on the content of the modules, for now use a stock image
# -- Display list in an ecommerce shopping style

# - Edit Module Interface #FIXME
# -- Display all the question objects related to that module

# - Add Module Function #FIXME
# -- User types name of the module they want to Add then it immediately jumps to the Edit Module Interface

# - Edit Question Object Interface #FIXME

# - Add Question Object Interface #FIXME

#PRIORITY 2:
# Create a seperate API driven database for this program to call #FIXME
# - This will take the user data and store it in a large bank
# - We will create one very large dictionary to store everything
# - {user_name: {
# questions_data: {}, 
# stats_data: {}, 
# settings_data: {}, 
# user_profile: {}
# user_modules: {} 
# }}
# Store modules that the user downloaded into local systemdata
# - This way we can store all users across millions to a single dictionary

# - Browse Server Modules #FIXME
# -- Similar to Edit Module Interface, but allows user to download/import modules located in the main server

# - User Profile Management Page #FIXME
# -- Allow the user to enter personal data as it relates to the date of memory loss prediction algorithm
# -- Allow the user to authenticate their account in order to upload their modules, or use server functions. (This means if users don't authenticate with the server they will not be able to permanently save their progress)

# - Question Object Generator #FIXME
# -- Allows the user to generate a module based on provided text
# -- User Input will be a list of documents (Individual notes, or one large book)
# -- If one large book then modules will be split up by chapter by default

#PRIORITY 3:
# - Mindmap Lesson Planning #FIXME
# -- Once we have lots of data and users lined up we can map and graph all this data together, how concepts relate to one another.
# -- Create a system to determine what the user knows and doesn't know.
# -- Master Graph of related concepts mapped against what the user does and doesn't know determines what the user is most ready for
# -- This in theory should accelerate learning, if the user is only introduced to adjacent concepts since they already exist in the mental framework of the user

# - Tutorial Page #FIXME
# -- Low Priority project, create a tutorial to guide new users through the program (Optional)
# -- Maybe someone else can figure this out? OR just make the UI/UX self explanatory

#####################
# Function Plans
# def rename_user(user_name) #FIXME
# -change the name of the files associated with that user

# def clean_question_object(question_object): #FIXME
# - strips a question object of any statistical properties so it can be stored in a module

# def write_questions_json_to_default_module(questions_data): #FIXME
# - Scans questions.json for any question object with a module name that does not exist in modules/, then writes those questions to wherever they need to be 

# def generate_question_object(data) #FIXME
# - AI program that takes academic material as input and generates question objects based on the data
# - FIXME Also update the related field
# - FIXME Also update the subject field
# - FIXME Also make sure every field is filled if possible
# - NOTE At least one question field and one answer field needs to be filled or the question object is not valid
# Custom Widgets:
class CustomAutoComplete_Widget():
    def __init__(self, page, items,col):
        self.page = page
        self.items = items
        self.col = col
        self.filtered_items = items.copy()
        self._build()

    def _build(self):
        self._assets()
        self.stack = ft.Stack(
            controls=[
                self.col,  # Base layer
                self.list_cont,     
            ],
        )
        self.page.add(self.text_field, self.stack)  # Add the stack

    def _assets(self):
        self.list_view = ft.ListView(
            expand=1,
            spacing=10,
            controls=[],
        )
        self.list_cont = ft.Container(
            content = self.list_view,
            bgcolor= ft.colors.WHITE,
        )
        self.text_field = ft.TextField(label="Filter list")
        self.text_field.on_change = self._filter_list

    def _filter_list(self, e):
        query = e.control.value.lower()
        if query:
            self.filtered_items = [item for item in self.items if query in item.lower()]
        else:
            self.filtered_items = []
        self.list_view.controls = [
            ft.ListTile(
                title=ft.Text(item),
                on_click=lambda e, item=item: self._on_list_item_click(item)
            ) for item in self.filtered_items
        ]
        self.page.update()

    def _on_list_item_click(self, item):
        self.text_field.value = item
        self.filtered_items = []
        self.list_view.controls = [] 
        self.page.update()
        print(f"Selected item: {item}") 

######################################################################################
#GLOBALS
#NOTE questions list gets popped to determine what the current question is
questions_list = []
current_question = {}
current_question_id = ""
user_profile_data = {}
question_object_data = system_data.get_question_object_data()
all_module_data = system_data.get_all_module_data()

#NOTE is_displayed is a status variable, and will switch from question to answer, when the interface is clicked this variable will determine what gets showed next
currently_displayed = "question"
#NOTE has_seen is a status variable, this variable determines whether or not the answer bar buttons are enabled or disabled
has_seen = False
#NOTE helps determine what should happen when the menu button is clicked
menu_active = False
#NOTE Detect whether or not any users actually exist (For first time users)
first_time_user = True
#NOTE Track whether or not there are any eligible questions remaining or not
questions_available_to_answer = False
CURRENT_USER = ""
CURRENT_UUID = ""

def main(page: ft.Page):
    page.title="Quizzer"
    page.theme_mode=ft.ThemeMode.DARK
    ###################################################################################################################################################
    # Function Defines
    ##NOTE For best practice, these functions listed should only include logic necessary to call a full function written in public_functions.py
    ## Functions relating to Login Screen
    def cancel_new_profile_entry(e: ft.ControlEvent):
        display_login_screen()

    def new_profile_screen(e: ft.ControlEvent):
        display_new_profile_input_screen()

    def generate_user_profile(e: ft.ControlEvent, user_name):
        print(user_name)
        system_data.add_new_user(user_name, question_object_data)
        display_login_screen()
        
    def initialize_program(e: ft.ControlEvent, user_name: str):
        global questions_list
        global questions_available_to_answer
        global current_question
        global current_question_id
        global user_profile_data
        global CURRENT_USER
        global CURRENT_UUID
        user_profile_data = system_data.get_user_data(user_name)
        # Assign Constants with appropriate values
        CURRENT_USER = user_profile_data["user_name"]
        CURRENT_UUID = user_profile_data["uuid"]
        print(f"Current User: <{CURRENT_USER}> WITH UUID: <{CURRENT_UUID}>")
        # Health Check functions
        # Sort out any unsorted questions into their respective "piles"
        user_profile_data["questions"] = system_data.sort_questions(user_profile_data, question_object_data)
         #updating is always a great idea
        # Populate the question list, then assign the current question object to be displayed
        questions_list, user_profile_data = generate_quiz.populate_question_list(user_profile_data, question_object_data)
        system_data.update_user_profile(user_profile_data)
        # The items in the questions list are references to the actual question objects in question object data
        # Therefore we can create this hierarchical function
        # handle no remaining questions to answer condition
        try:
            current_question_id = questions_list.pop()
            current_question = question_object_data[current_question_id]
            questions_available_to_answer = True
        except IndexError as e:
            print(f"    {e}, There are no remaining questions left to answer")
            # We should display some default information to the question object display to indicate the issue to the user
            questions_available_to_answer = False
        print(current_question_id)
        print(current_question)
        page.clean()
        refresh_question_object_display_with_question()
        
    def determine_user_list():
        '''
        Updates the current list of users to provide to the drop down menu
        '''
        current_user_list = system_data.get_user_list()
        return current_user_list
    def display_new_profile_input_screen(e: ft.ControlEvent = None):
        page.clean()
        current_user_list = determine_user_list()
        if current_user_list != []:
            user_name_dropdown_select = ft.Dropdown(visible=True,label="User Name",width=250,options=[ft.dropdown.Option(i) for i in current_user_list])
        else:
            user_name_dropdown_select = ft.Dropdown(visible=True,disabled=True,label="Create a New User",width=250,options=[])
        submit_add_profile = ft.ElevatedButton(text="Submit", on_click=lambda e: generate_user_profile(e, user_name_field.value), visible=True)

        user_name_field = ft.TextField(label="User Name", width=250,visible=True)

        cancel_add_profile = ft.ElevatedButton(text="Cancel", on_click=cancel_new_profile_entry, visible=True)

        user_name_row = ft.Row(alignment=ft.MainAxisAlignment.CENTER,controls=[user_name_field])

        login_button_row = ft.Row(alignment=ft.MainAxisAlignment.CENTER,controls=[submit_add_profile,cancel_add_profile])
        ###################################################################################################################################################
        # Page Defines
        new_profile_screen = ft.Column(alignment=ft.MainAxisAlignment.CENTER,expand=True,spacing=25,controls=[user_name_row,login_button_row])
        page.add(new_profile_screen)
        page.update()
    def display_login_screen(e: ft.ControlEvent = None):
        page.clean()
        current_user_list = determine_user_list()
        if current_user_list != []:
            user_name_dropdown_select = ft.Dropdown(visible=True,label="User Name",width=250,options=[ft.dropdown.Option(i) for i in current_user_list])
        else:
            user_name_dropdown_select = ft.Dropdown(visible=True,disabled=True,label="Create a New User",width=250,options=[])
        submit_login = ft.ElevatedButton(text="Login", on_click=lambda e: initialize_program(e, user_name_dropdown_select.value), visible=True)
        add_profile = ft.ElevatedButton(text="Add New User", on_click=new_profile_screen, visible=True)
        password_field = ft.TextField(label="Password", value="Not Implemented Yet", width=250, disabled=True)
        user_name_row = ft.Row(alignment=ft.MainAxisAlignment.CENTER,controls=[user_name_dropdown_select])
        password_row = ft.Row(alignment=ft.MainAxisAlignment.CENTER,controls=[password_field])
        login_button_row = ft.Row(alignment=ft.MainAxisAlignment.CENTER,controls=[add_profile,submit_login])
        ###################################################################################################################################################
        # Page Defines
        login_screen = ft.Column(alignment=ft.MainAxisAlignment.CENTER,expand=True,spacing=25,controls=[user_name_row,password_row,login_button_row])
        page.add(login_screen)
        page.update()

    display_login_screen()
    ###################################################################################################################################################
    ###################################################################################################################################################
    ###################################################################################################################################################
    ###################################################################################################################################################
    ###################################################################################################################################################
    ###################################################################################################################################################
    ## Waiting Screen #FIXME Some cool animations, if initialization starts to take longer, then we will need this
    # Function Defines
    # Element Defines
    # Container Defines
    # Page Defines



    ###################################################################################################################################################
    ###################################################################################################################################################
    ###################################################################################################################################################
    ###################################################################################################################################################
    ###################################################################################################################################################
    ###################################################################################################################################################
    ## For Main Body Application (Question Answer Loop)
    # Function Defines
    def get_next_question():
        print(f"def get_next_question()")
        global questions_available_to_answer
        global questions_list
        global user_profile_data
        global question_object_data
        global current_question
        global current_question_id
        # If the current list is empty then
        if len(questions_list) <= 0:
            # Get a new list
            questions_list, user_profile_data = generate_quiz.populate_question_list(user_profile_data, question_object_data)
        # List may or may not be empty still
        if questions_list == []:
            # If the list is still empty, then we likely have no remaining questions in our is_eligible pile
            # Check the circulating_not_eligible pile for eligible questions
            user_profile_data = system_data.update_circulating_non_eligible_questions(user_profile_data, question_object_data)
            # Try and get another list
            questions_list, user_profile_data = generate_quiz.populate_question_list(user_profile_data, question_object_data)
        # This list could be empty if no eligible questions were found, so . . .
        try:
            # Attempt to grab a question from the list which may or may not be empty
            current_question_id = questions_list.pop()
            current_question = question_object_data[current_question_id]
            questions_available_to_answer = True
            # Whenever we get a new_questioin we will need to reset the display with the question, ensure you are calling refresh_display when you get_next_question
        except IndexError as e:
            # If there are no remaining question even still, then we should notify the user. Set a boolean value to track this
            print(f"    {e}, There are no remaining questions left to answer")
            # We should display some default information to the question object display to indicate the issue to the user
            questions_available_to_answer = False
    def build_stat_list():
        '''
        Used to define what stats will appear in the header of the program, if any at all.
        These will likely be stats relating to the existing question, how many questions are left, and other immediately relevant information
        '''
        global questions_available_to_answer
        global user_profile_data
        global questions_list
        global current_question
        global current_question_id
        stat_list = []
        if questions_available_to_answer == False:
            # If there are no questions to answer right now then we have no stats to display, return an empty list
            return stat_list
        stats_data = user_profile_data["stats"]
        todays_date = str(date.today())
        
        print("building list of stats to display to the user")
        question_subject = ft.Text(value=f"Subject: {current_question['subject']}")
        questions_in_quiz = ft.Text(value=f"Questions in Current Quiz: {len(questions_list)}")
        revision_streak = ft.Text(value=f"RS: {user_profile_data['questions']['in_circulation_is_eligible'][current_question_id]['revision_streak']}")
        new_average_daily_questions = ft.Text(value=f"AVG New Daily Questions: {stats_data['average_num_questions_entering_circulation_daily']:.2f}")
        current_eligible_questions = ft.Text(value=f"Qa's today: {stats_data['current_eligible_questions']}")
        total_questions_answered = ft.Text(value=f"Total Answered: {stats_data['total_questions_answered']}")
        try:
            answered_today = ft.Text(value=f"Answered Today: {stats_data['questions_answered_by_date'][todays_date]}")
        except KeyError:
            answered_today = ft.Text(value="Answered Today: 0")
        
        stat_list.append(questions_in_quiz)
        stat_list.append(new_average_daily_questions)
        stat_list.append(revision_streak)
        stat_list.append(current_eligible_questions)
        stat_list.append(total_questions_answered)
        stat_list.append(answered_today)
        stat_list.append(question_subject)    
        return stat_list
    
    def display_menu_page(e: ft.ControlEvent):
        '''
        Displays the menu page
        '''
        global menu_active
        if menu_active == False:
            page.clean()
            page.add(side_bar_container)
            page.update()
            menu_active = True

        elif menu_active == True:
            page.clean()
            if currently_displayed == "question":
                refresh_question_object_display_with_question()
            elif currently_displayed == "answer":
                refresh_question_object_display_with_answer()
            page.update()
            menu_active = False

        else:
            print("Something unexpected?")
    def question_answered(e: ft.ControlEvent, status: int) -> None:
        '''
        Calls backend update_score function with status of correct
        '''
        print(f"def question_answered(e: ft.ControlEvent, status: int) -> None")
        
        global questions_available_to_answer
        # If the case is that there are no questions able to answered then we simply disable the function, when button is pressed, go ahead and attempt to get_next_question
        if questions_available_to_answer == False:
            get_next_question()
            return None

        global user_profile_data
        global current_question
        global questions_list
        global current_question_id
        global currently_displayed
        global has_seen
        yes_button.disabled=True
        no_button.disabled=True
        page.update()
        has_seen = False
        currently_displayed = "question"
        print(f"    Updating question <{current_question_id}> with status of <{status}>")
        user_profile_data = system_data.update_score(status, current_question_id, user_profile_data, question_object_data)
        system_data.update_user_profile(user_profile_data) # Save information every time a question is answered
        get_next_question()
        refresh_question_object_display_with_question()

    def skip_to_next_question(e: ft.ControlEvent):
        '''
        Skips to next question, does not update any statistics on the backend
        '''
        print(f"def skip_to_next_question(e: ft.ControlEvent)")
        print("    Skipping question")
        # Disable skip button when it's pressed
        skip_button.disabled=True
        global user_profile_data
        global questions_available_to_answer
        # Attempt to get next_question if we have none available
        if questions_available_to_answer == False:
            get_next_question()
            return None
        global current_question
        global questions_list
        global currently_displayed
        global has_seen
        
        page.update()
        get_next_question()
        currently_displayed = "question"
        has_seen = False
        # Reenable skip button once all functions are done processing -> this prevents erros caused by running this function before the last iteration is complete
        skip_button.disabled=False
        refresh_question_object_display_with_question()
        
        
    def flip_question_answer(e: ft.ControlEvent):
        '''
        Changes the display to show the question objects question or answer, whichever is not currently displayed
        '''
        global questions_available_to_answer
        global current_question
        global current_question_id
        global currently_displayed
        global has_seen
        # If we end up in a situation where there are no questions to answer, we will check if there are questions everytime we flip the card
        if questions_available_to_answer == False:
            get_next_question()
        # Determine whether we should change the display to the answer or question fields
        if currently_displayed == "question":
            refresh_question_object_display_with_answer()
            currently_displayed = "answer"
        elif currently_displayed == "answer":
            refresh_question_object_display_with_question()
            currently_displayed = "question"
        else:
            print("hardcoded variable has different value than expected?")
            raise ValueError
        
        # enable yes and no buttons once the user sees the answer -> You can't decide on whether you got it right or not before you've seen the answer (no matter how confident you might be)
        if has_seen == False:
            yes_button.disabled = False
            no_button.disabled = False
        page.update()
    # Initial Defines
    ## icons
    menu_icon = ft.Icon(name=ft.icons.MENU_SHARP, color=ft.colors.BLACK)
    yes_icon = ft.Icon(name=ft.icons.CHECK_CIRCLE, color=ft.colors.WHITE)
    no_icon = ft.Icon(name=ft.icons.NOT_INTERESTED, color=ft.colors.WHITE)
    skip_icon = ft.Icon(name=ft.icons.SKIP_NEXT, color=ft.colors.BLACK)
    # Main Interface (Header) #NOTE Includes a brief display of important metrics, and the menu button
    menu_button = ft.ElevatedButton(content=menu_icon, bgcolor="white", on_click=display_menu_page)
    stat_list = []
    main_page_header_stat_display = ft.Column(expand=True,height=50,controls=stat_list,wrap=True)#FIXME
    main_page_header = ft.Row(expand=False,alignment=ft.MainAxisAlignment.START,controls= [menu_button,main_page_header_stat_display])
    
    # Main Interface (Question Answer Display Box) #NOTE The container is constructed, using the data derived from the question object.
    question_object_text_display = ft.Text(value="No Question Loaded")
    main_page_qo_text_row = ft.Row(alignment=ft.MainAxisAlignment.CENTER,controls=[question_object_text_display])
    
    question_object_audio_controls = ft.Text(value="No Questions Loaded")
    main_page_qo_audio_row = ft.Row(alignment=ft.MainAxisAlignment.CENTER,controls=[question_object_audio_controls])
    
    question_object_image_display = ft.Text(value="No Questions Loaded")
    main_page_qo_image_row = ft.Row(expand=True,alignment=ft.MainAxisAlignment.CENTER,controls=[question_object_image_display])
    
    question_object_video_display = ft.Text(value="No Questions Loaded")
    main_page_qo_video_row = ft.Row(expand=True,alignment=ft.MainAxisAlignment.CENTER,controls=[question_object_video_display])
    
    main_page_question_object_data = ft.Column(expand=True,alignment=ft.MainAxisAlignment.CENTER,controls=[main_page_qo_text_row,main_page_qo_audio_row,main_page_qo_image_row,main_page_qo_video_row])
    main_page_question_object_display = ft.Container(expand=True,padding=20,ink=True,ink_color=ft.colors.GREY_500,content=main_page_question_object_data,on_click=flip_question_answer)
    
    # Main Interface (User Scoring Mechanism), will not need refreshed, contains buttons to skip the current question, answer is correct or incorrect defined by a green or red buttons.
    yes_button = ft.ElevatedButton(content=yes_icon, bgcolor="green", on_click=lambda e: question_answered(e , status="correct"), disabled=True)
    no_button = ft.ElevatedButton(content=no_icon, bgcolor="red", on_click=lambda e: question_answered(e , status="incorrect"), disabled=True)
    skip_button = ft.ElevatedButton(content=skip_icon, bgcolor="white", on_click=skip_to_next_question, disabled=False) #Always allow skip function
    main_page_answer_bar = ft.Row(alignment=ft.MainAxisAlignment.SPACE_AROUND,spacing=25,controls=[yes_button,skip_button,no_button])
    
    main_page = ft.Column(expand=True,controls=[main_page_header,main_page_question_object_display,main_page_answer_bar])
    
    def refresh_question_object_display_with_question():
        '''
        Changes the page to the main interface with the current question_object's question fields displayed
        '''
        #NOTE, tried to break this up into functions, but that didn't work for some reason, I'm assuming it has to do with scope, but I haven't quite learned how to properly manipulate scope just yet.
        # Refresh stats header
        global questions_available_to_answer
        global current_question
        # Boolean was set by functions called by the buttons
        if questions_available_to_answer == False:
            current_question = {}
            current_question["question_text"] = "There are no questions available to answer, consider adding more, or take a break for the day"
            current_question["answer_text"] = "You can flip this all day long, but there are no questions available to show right now"
        
        stat_list = build_stat_list()
        main_page_header_stat_display = ft.Column(expand=True,height=80,controls=stat_list,wrap=True)#FIXME
        main_page_header = ft.Row(expand=False,alignment=ft.MainAxisAlignment.START,controls= [
            menu_button,
            main_page_header_stat_display,
            ft.Row(expand=True, alignment=ft.MainAxisAlignment.END, controls=[ft.IconButton(icon=ft.icons.ADD, icon_color=ft.colors.BLACK, tooltip="Add A New Question", bgcolor=ft.colors.WHITE,
                                                                                            on_click=display_add_question_interface)])
            ])
        
        # Set all fields to None
        controls_list = []
        question_object_text_display = None
        main_page_qo_text_row = None
        question_object_audio = None
        main_page_qo_audio_row = None
        question_object_image_display = None
        main_page_qo_image_row = None
        question_object_video_display = None
        main_page_qo_video_row = None
 
        # Construct each field only if data for that field exists
        if current_question.get("question_text") != None:
            question_object_text_display = ft.Text(value=current_question["question_text"], size=30)
            main_page_qo_text_row = ft.Row(alignment=ft.MainAxisAlignment.SPACE_AROUND,controls=[question_object_text_display], wrap=True)
            controls_list.append(main_page_qo_text_row)
        if current_question.get("question_audio") != None:
            question_object_audio = ft.Audio(src=current_question["question_audio"], autoplay=True,)
            main_page_qo_audio_row = ft.Row(alignment=ft.MainAxisAlignment.SPACE_AROUND,controls=[question_object_audio])
            controls_list.append(main_page_qo_audio_row)
        if current_question.get("question_image") != None:
            print("We have an image!!!")
            source = helper.get_absolute_media_path(current_question["question_image"], current_question)
            question_object_image_display = ft.Image(src=source, fit=ft.ImageFit.SCALE_DOWN)
            main_page_qo_image_row = ft.Row(alignment=ft.MainAxisAlignment.SPACE_AROUND,controls=[question_object_image_display])
            controls_list.append(main_page_qo_image_row)
        if current_question.get("question_video") != None:
            #FIXME
            raise NotImplementedError
            question_object_video_display = ft.Video()
            main_page_qo_video_row = ft.Row(expand=True,alignment=ft.MainAxisAlignment.CENTER,controls=[question_object_video_display])
            controls_list.append(main_page_qo_video_row)
        # Optional condition, if the text is the only thing existing, then let it expand to fill the container
        if ((current_question.get("question_image") == None) and
            (current_question.get("question_video") == None)):
            main_page_qo_text_row.expand = True
        main_page_question_object_data = ft.Column(expand=False,
                                                   controls=controls_list,
                                                   scroll=ft.ScrollMode.ALWAYS,
                                                   alignment=ft.MainAxisAlignment.SPACE_AROUND,
                                                   horizontal_alignment=ft.MainAxisAlignment.SPACE_AROUND)
        
        main_page_question_object_button = ft.Container(expand=False,
                                                        ink=True,
                                                        ink_color=ft.colors.GREY_500,
                                                        content=main_page_question_object_data,
                                                        on_click=flip_question_answer,
                                                        )
        
        main_page_question_object_display = ft.Column(alignment=ft.MainAxisAlignment.SPACE_AROUND,
                                                      horizontal_alignment=ft.MainAxisAlignment.SPACE_AROUND,
                                                      expand=True,
                                                      controls=[main_page_question_object_button])
        main_page_question_object_button.width = page.width
        main_page_question_object_button.height = (page.height)
        
        # Bottom of Page
        main_page_answer_bar = ft.Row(alignment=ft.MainAxisAlignment.SPACE_AROUND,spacing=25,controls=[yes_button,skip_button,no_button],height=50)
        main_page = ft.Column(expand=True,controls=[main_page_header,main_page_question_object_display,main_page_answer_bar])
        page.clean()
        page.add(main_page)

    def refresh_question_object_display_with_answer():
        '''
        Changes the page to the main interface with the current question_object's answer fields displayed
        '''
        stat_list = build_stat_list()
        main_page_header_stat_display = ft.Column(expand=True,height=80,controls=stat_list,wrap=True)#FIXME
        main_page_header = ft.Row(expand=False,alignment=ft.MainAxisAlignment.START,controls= [
            menu_button,
            main_page_header_stat_display,
            ft.Row(expand=True, alignment=ft.MainAxisAlignment.END, controls=[ft.IconButton(icon=ft.icons.ADD, icon_color=ft.colors.BLACK, tooltip="Add A New Question", bgcolor=ft.colors.WHITE,
                                                                                            on_click=display_add_question_interface)])
            ])
        
        controls_list = []
        question_object_text_display = None
        main_page_qo_text_row = None
        question_object_audio = None
        main_page_qo_audio_row = None
        question_object_image_display = None
        main_page_qo_image_row = None
        question_object_video_display = None
        main_page_qo_video_row = None
        # Construct each field only if data for that field exists
        if current_question.get("answer_text") != None:
            question_object_text_display = ft.Text(value=current_question["answer_text"], size=30)
            main_page_qo_text_row = ft.Row(alignment=ft.MainAxisAlignment.SPACE_AROUND,controls=[question_object_text_display], wrap=True)
            controls_list.append(main_page_qo_text_row)
        if current_question.get("answer_audio") != None:
            question_object_audio = ft.Audio(src=current_question["answer_audio"], autoplay=True,)
            main_page_qo_audio_row = ft.Row(alignment=ft.MainAxisAlignment.SPACE_AROUND,controls=[question_object_audio])
            controls_list.append(main_page_qo_audio_row)
        if current_question.get("answer_image") != None:
            source = helper.get_absolute_media_path(current_question["answer_image"], current_question)
            question_object_image_display = ft.Image(src=source, fit=ft.ImageFit.SCALE_DOWN)
            main_page_qo_image_row = ft.Row(alignment=ft.MainAxisAlignment.SPACE_AROUND,controls=[question_object_image_display])
            controls_list.append(main_page_qo_image_row)
        if current_question.get("answer_video") != None:
            #FIXME
            raise NotImplementedError
            question_object_video_display = ft.Video()
            main_page_qo_video_row = ft.Row(expand=True,alignment=ft.MainAxisAlignment.CENTER,controls=[question_object_video_display])
            controls_list.append(main_page_qo_video_row)
        
        main_page_question_object_data = ft.Column(expand=False,
                                                   controls=controls_list,
                                                   scroll=ft.ScrollMode.ALWAYS,
                                                   alignment=ft.MainAxisAlignment.SPACE_AROUND,
                                                   horizontal_alignment=ft.MainAxisAlignment.SPACE_AROUND)
        
        main_page_question_object_button = ft.Container(expand=False,
                                                        ink=True,
                                                        ink_color=ft.colors.GREY_500,
                                                        content=main_page_question_object_data,
                                                        on_click=flip_question_answer,
                                                        )
        
        main_page_question_object_display = ft.Column(alignment=ft.MainAxisAlignment.SPACE_AROUND,
                                                      horizontal_alignment=ft.MainAxisAlignment.SPACE_AROUND,
                                                      expand=True,
                                                      controls=[main_page_question_object_button])
        main_page_question_object_button.width = page.width
        main_page_question_object_button.height = (page.height)
        main_page_answer_bar = ft.Row(alignment=ft.MainAxisAlignment.SPACE_AROUND,spacing=25,controls=[yes_button,skip_button,no_button])
        main_page = ft.Column(expand=True,controls=[main_page_header,main_page_question_object_display,main_page_answer_bar])
        page.clean()
        page.add(main_page)
    ###################################################################################################################################################
    ###################################################################################################################################################
    ###################################################################################################################################################
    ###################################################################################################################################################
    ###################################################################################################################################################
    ###################################################################################################################################################
    # Add and Edit Question pages

    def display_add_question_interface(e: ft.ControlEvent):
        global currently_displayed
        global user_profile_data
        global question_object_data
        global all_module_data
        #FIXME conditional tutorial page
        # Define the controls
        ############################
        # No option will be provided to enter own unique id
        print(f"The width of the page is: {page.width}")
        subject_data = system_data.get_subject_data()
        concept_data = system_data.get_concept_data()

        add_question_main_header = ft.Row(alignment=ft.MainAxisAlignment.CENTER, controls=[ft.Text(value="Add New Question", size=36)])

        form_fields = ft.Row(alignment=ft.MainAxisAlignment.SPACE_BETWEEN)
        left_side_column = ft.Column(alignment=ft.MainAxisAlignment.START, horizontal_alignment=ft.CrossAxisAlignment.START)
        right_side_column = ft.Column(alignment=ft.MainAxisAlignment.START, horizontal_alignment=ft.CrossAxisAlignment.START)
        form_fields.controls = [left_side_column, right_side_column]
        ######
        def replace_primary_subject_with_textfield(e: ft.ControlEvent):
            del left_side_column.controls[1]
            left_side_column.controls.insert(1, primary_subject_textfield_row)
            page.update()
        def primary_subject_back(e:ft.ControlEvent):
            del left_side_column.controls[1]
            left_side_column.controls.insert(1, primary_subject_line)
            page.update()

        primary_subject_textfield = ft.TextField(width=200)
        primary_subject_back_button = ft.IconButton(icon=ft.icons.ARROW_BACK, icon_color=ft.colors.BLACK, tooltip="Select from from list", bgcolor=ft.colors.WHITE, on_click=primary_subject_back)
        primary_subject_textfield_row = ft.Row(controls=[primary_subject_textfield, primary_subject_back_button])

        primary_subject_text = ft.Text(value="Primary Subject", size=24,
                                        tooltip="What is the Primary Subject, or Field of Study, of this question?\n For example is this a biology question, anatomy, mathematics, calculus, history, etc.")
        
        primary_subject_input = ft.AutoComplete(suggestions=[ft.AutoCompleteSuggestion(key=i, value=i) for i in subject_data.keys()])
        add_new_primary_subject_button = ft.IconButton(icon=ft.icons.ADD, icon_color=ft.colors.BLACK, tooltip="Add a subject that isn't in the list", bgcolor=ft.colors.WHITE, on_click=replace_primary_subject_with_textfield)
        primary_subject_line = ft.Row(controls=[ft.Column(controls=[ft.Stack(controls=[primary_subject_input],width=200), add_new_primary_subject_button], height=75, wrap=True)])
        left_side_column.controls.append(primary_subject_text)
        left_side_column.controls.append(primary_subject_line)

        ######
        def replace_module_name_with_textfield(e: ft.ControlEvent):
            del right_side_column.controls[1]
            right_side_column.controls.insert(1, module_name_textfield_row)
            page.update()
        def module_name_back(e: ft.ControlEvent):
            del right_side_column.controls[1]
            right_side_column.controls.insert(1, module_line)
            page.update()

        module_name_textfield = ft.TextField(width=200)
        module_name_back_button = ft.IconButton(icon=ft.icons.ARROW_BACK, icon_color=ft.colors.BLACK, tooltip="Add a subject that isn't in the list", bgcolor=ft.colors.WHITE, on_click=module_name_back)
        module_name_textfield_row = ft.Row(controls=[module_name_textfield, module_name_back_button])

        module_name_text = ft.Text(value="Define the Module:", size=24, tooltip="What module does the question belong to?\n Begin by typing the name of the module, you'll be given a list of suggestions based on what modules already exist by that name\n You can contribute to any module \n BE AWARE: adding a question to a pre-existing module, will import that module into your profile\n Please Avoid adding duplicate questions to a module")
        module_name_input = ft.AutoComplete(suggestions=[ft.AutoCompleteSuggestion(key=i, value=i) for i in all_module_data.keys()])
        add_new_module_button = ft.IconButton(icon=ft.icons.ADD, icon_color=ft.colors.BLACK, tooltip="Add a subject that isn't in the list", bgcolor=ft.colors.WHITE, on_click=replace_module_name_with_textfield)
        module_line = ft.Row(controls=[ft.Column(controls=[ft.Stack(controls=[module_name_input],width=200), add_new_module_button], height=75, wrap=True)])
        right_side_column.controls.append(module_name_text)
        right_side_column.controls.append(module_line)

        # single_field_row = ft.Row(alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
        #                           controls=[ft.Column(controls=[ft.Stack(controls=[module_name_input],width=250), add_new_module_button],     height=75, wrap=True)])
        # Need to be able to delete entries before submission
        ###
        def replace_related_subjects_with_textfield(e: ft.ControlEvent):
            del left_side_column.controls[3]
            left_side_column.controls.insert(3, related_subjects_textfield_row)
            page.update()
        def related_subjects_back(e: ft.ControlEvent):
            del left_side_column.controls[3]
            left_side_column.controls.insert(3, subject_entry_row)
            page.update()
        def add_to_related_subjects(e: ft.ControlEvent, subject_inputted):
            current_subject_list = [i for i in subject.value.split("\n")]
            # Avoid duplication
            if subject_inputted not in current_subject_list:
                if subject.value == None or subject.value == "":
                    subject.value += f"{subject_inputted}"
                else:
                    subject.value += f"\n{subject_inputted}"
            page.update()
        def clear_related_subjects_field(e: ft.ControlEvent):
            subject.value=""
            page.update()
        related_subjects_textfield = ft.TextField(width=200, on_submit=lambda e: add_to_related_subjects(e, related_subjects_textfield.value))
        related_subjects_back_button = ft.IconButton(icon=ft.icons.ARROW_BACK, icon_color=ft.colors.BLACK, tooltip="Clear The Related Subjects Input Field", bgcolor=ft.colors.WHITE, on_click=related_subjects_back)
        related_subjects_textfield_row = ft.Row(controls=[related_subjects_textfield, related_subjects_back_button])
        subject = ft.TextField(label="Related Subjects",
                               tooltip="What other subjects relate to this question?\n For example it might be a calculus question, but calculus also falls under mathematics, \nThe question may also be referrencing a historical event, thus related to history as well",
                               multiline=True, disabled=True, width=200)
        clear_subject_button = ft.IconButton(icon=ft.icons.CLEAR, icon_color=ft.colors.BLACK, tooltip="Clear The Related Subjects Input Field", bgcolor=ft.colors.WHITE, on_click=clear_related_subjects_field)
        subject_input_row = ft.Row(controls=[subject, clear_subject_button])
        left_side_column.controls.append(subject_input_row)


        subject_auto_complete = ft.AutoComplete(suggestions=[ft.AutoCompleteSuggestion(key=i, value=i) for i in subject_data.keys()],on_select=lambda e: add_to_related_subjects(e, e.selection.value))
        add_new_subject_button = ft.IconButton(icon=ft.icons.ADD, icon_color=ft.colors.BLACK, tooltip="Add a subject that isn't in the list", bgcolor=ft.colors.WHITE, on_click=replace_related_subjects_with_textfield)
        subject_entry_row = ft.Row(controls=[ft.Column(controls=[ft.Stack(controls=[subject_auto_complete],width=200), add_new_subject_button], height=75, wrap=True)])
        left_side_column.controls.append(subject_entry_row)
        
        ###
        def replace_related_concepts_with_textfield(e: ft.ControlEvent):
            del right_side_column.controls[3]
            right_side_column.controls.insert(3, related_concepts_textfield_row)
            page.update()
        def related_concepts_back(e: ft.ControlEvent):
            del right_side_column.controls[3]
            right_side_column.controls.insert(3, concept_entry_row)
            page.update()
        def add_to_related_concepts(e: ft.ControlEvent, concept_inputted):
            current_concept_list = [i for i in related.value.split("\n")]
            # Avoid duplication
            if concept_inputted not in current_concept_list:
                if related.value == None or related.value == "":
                    related.value += f"{concept_inputted}"
                else:
                    related.value += f"\n{concept_inputted}"
            page.update()
        def clear_related_concepts_field(e: ft.ControlEvent):
            related.value=""
            page.update()

        related_concepts_textfield = ft.TextField(width=200, on_submit=lambda e: add_to_related_concepts(e, related_concepts_textfield.value))
        related_concepts_back_button = ft.IconButton(icon=ft.icons.ARROW_BACK, icon_color=ft.colors.BLACK, tooltip="Clear the Related Concepts Input Field", bgcolor=ft.colors.WHITE, on_click=related_concepts_back)
        related_concepts_textfield_row = ft.Row(controls=[related_concepts_textfield, related_concepts_back_button])

        related = ft.TextField(label="Related Concepts and Terms",
                               tooltip="What concepts and terms are related to this question?\nFor example the question What year was xyz invented and who invented it? points to the term xyz, to the historical period, and to the individual\n",
                               multiline=True, disabled=True, width=200)
        clear_related_button = ft.IconButton(icon=ft.icons.CLEAR, icon_color=ft.colors.BLACK, tooltip="Clear the Related Concepts Input Field", bgcolor=ft.colors.WHITE, on_click=clear_related_concepts_field)
        related_concepts_input_row = ft.Row(controls=[related, clear_related_button])
        right_side_column.controls.append(related_concepts_input_row)

        concept_auto_complete = ft.AutoComplete(suggestions=[ft.AutoCompleteSuggestion(key=i, value=i) for i in concept_data.keys()],on_select=lambda e: add_to_related_concepts(e, e.selection.value))
        add_new_concept_button = ft.IconButton(icon=ft.icons.ADD, icon_color=ft.colors.BLACK, tooltip="Add a concept that isn't in the list", bgcolor=ft.colors.WHITE, on_click=replace_related_concepts_with_textfield)
        concept_entry_row = ft.Row(controls=[ft.Column(controls=[ft.Stack(controls=[concept_auto_complete],width=200), add_new_concept_button], height=75, wrap=True)])
        right_side_column.controls.append(concept_entry_row)

        ############################
        question_text = ft.TextField(label="Question Text", multiline=True, tooltip="What's the Question?",width=400) #FIXME multiline text box
        question_image = ft.Text(value="Question Image", tooltip="Is there an image that goes with the question?")
        question_image_upload_button = ft.ElevatedButton(text="Upload Question's Image")
        question_audio = ft.Text(value="Question Audio", tooltip="Is there audio that goes with the question?")
        question_audio_upload_button = ft.ElevatedButton(text="Upload Question's Audio")
        question_video = ft.Text(value="Question Video", tooltip="Is there a video that goes with the question?")
        question_video_upload_button = ft.ElevatedButton(text="Upload Question's Video")
        question_image_upload_row = ft.Row(controls=[question_image, question_image_upload_button])
        question_audio_upload_row = ft.Row(controls=[question_audio, question_audio_upload_button])
        question_video_upload_row = ft.Row(controls=[question_video, question_video_upload_button])
        


        ############################
        answer_text = ft.TextField(label="Answer Text") #FIXME multiline text box
        answer_image = ft.Text(value="Answer Image")
        answer_image_upload_button = ft.ElevatedButton(text="Upload Answer's Image")
        answer_audio = ft.Text(value="Answer Audio")
        answer_audio_upload_button = ft.ElevatedButton(text="Upload Answer's Audio")
        answer_video = ft.Text(value="Answer Video")
        answer_video_upload_button = ft.ElevatedButton(text="Upload Answer's Video")
        answer_image_upload_row = ft.Row(controls=[answer_image, answer_image_upload_button])
        answer_audio_upload_row = ft.Row(controls=[answer_audio, answer_audio_upload_button])
        answer_video_upload_row = ft.Row(controls=[answer_video, answer_video_upload_button])

        ############################
        # Submission Buttons
        submit_button = ft.IconButton(icon=ft.icons.UPLOAD, icon_color=ft.colors.WHITE)
        def exit_add_question_interface(e):
            if currently_displayed == "question":
                refresh_question_object_display_with_question()
            else:
                refresh_question_object_display_with_answer()
        cancel_button = ft.IconButton(icon=ft.icons.CANCEL, icon_color=ft.colors.WHITE, on_click=exit_add_question_interface)
        submission_button_row = ft.Row(alignment=ft.MainAxisAlignment.SPACE_AROUND, controls=[submit_button, cancel_button])

        page.clean()
        page.add(
            menu_button,
            add_question_main_header,
            form_fields,
            ft.Text(value="Question Fields", tooltip="At least one question field must be filled", size=24),
            question_text,
            question_image_upload_row,
            question_audio_upload_row,
            question_video_upload_row,
            ft.Text(value="Answer Fields", tooltip="At least one answer field must be filled", size=24),
            answer_text,
            answer_image_upload_row,
            answer_audio_upload_row,
            answer_video_upload_row,
            submission_button_row
        )








    ###################################################################################################################################################
    ###################################################################################################################################################
    ###################################################################################################################################################
    ###################################################################################################################################################
    ###################################################################################################################################################
    ###################################################################################################################################################
    # Menu Sidebar
    ## Initial Variable Defines
    ### Icons
    under_construction_icon = ft.Icon(name=ft.icons.CONSTRUCTION)
    #############################################################################
    #############################################################################
    #############################################################################
    # Logout Button
    logout_icon = ft.Icon(name=ft.icons.LOGOUT, color=ft.colors.WHITE)
    logout_text = ft.Text(value="LOGOUT")
    logout_row = ft.Row(controls=[logout_icon, logout_text])
    logout_button = ft.ElevatedButton(content=logout_row, on_click=display_login_screen)

    #############################################################################
    #############################################################################
    #############################################################################
    # Settings Button & Settings Page
    settings_page_header = ft.Row(controls=[menu_button], alignment=ft.MainAxisAlignment.START, expand=True)
    settings_column = ft.Column(wrap=True, expand=True, controls=[settings_page_header])
    settings_page = ft.Container(content=settings_column)

    def update_user_settings(e: ft.ControlEvent):
        global user_profile_data
        key = e.control.label
        field_value = e.control.value
        data = e.control.data
        # print(e.control)
        # print(e.control.data)
        public_functions.update_setting(key, field_value, data, user_profile_data)

    def display_settings_page(e: ft.ControlEvent) -> None:
        #FIXME scrolling clock display for due_date_sensitivity
        # Dynamically generated page based on the users settings.json
        global user_profile_data
        page.clean()
        settings_data = user_profile_data["settings"]
        settings_data["module_settings"]["module_status"] = helper.sort_dictionary_keys(settings_data["module_settings"]["module_status"])
        # Load in menu button at top
        settings_page_header = ft.Row(controls=[menu_button], alignment=ft.MainAxisAlignment.START)
        settings_column = ft.Column(expand=True, controls=[settings_page_header],scroll=ft.ScrollMode.ALWAYS)
        # Multiple for loops
        ## In order, display settings with int values, then string values, then list values, then dict values ⋃
        # Display int based settings
        settings_column.controls.append(ft.Text(value="Settings Page", size = 36))
        settings_column.controls.append(ft.Text(value="Integer Settings", size = 24))
        for option, option_value in settings_data.items():
            if isinstance(option_value, int):
                settings_column.controls.append(ft.TextField(label=str(option), value=str(option_value), data={
                    "full_settings_key": f"settings_data[{option}]",
                    "key": f"{option}"
                }, on_change=lambda e: update_user_settings(e)))


        # Display nested settings
        for option, option_value in settings_data.items():
            if isinstance(option_value, dict):
                temp_cont_header = ft.Text(value=option, size=24)
                # Serves as a large "block" containing all the settings nested under the accessed key
                temp_cont_column = ft.Column(controls=[temp_cont_header], wrap=True, scroll=ft.ScrollMode.ALWAYS)
                

                for nest_one_key, nest_one_val in option_value.items():
                    if isinstance(nest_one_val, bool):
                        check_box_text = ft.Text(value=nest_one_key,size=16)
                        check_box = ft.Checkbox(value=nest_one_val, data={
                            "full_settings_key": f"settings_data[{option}][{nest_one_key}]",
                            "key": f"{nest_one_key}"
                        }, on_change=update_user_settings)
                        check_box_row = ft.Row(controls=[check_box_text,check_box])
                        temp_cont_column.controls.append(
                            check_box_row
                        )


                    if isinstance(nest_one_val, dict):
                        nest_two_text = ft.Text(value=nest_one_key)
                        nest_two_row = ft.Row(controls=[nest_two_text])
                        for nest_two_key, nest_two_val in nest_one_val.items():
                            if nest_two_key == "priority":
                                nest_two_row.controls.append(
                                    ft.TextField(label="Priority", value=nest_two_val, width=70, data={
                                        "full_settings_key": f"settings_data[{option}][{nest_one_key}][{nest_two_key}]",
                                        "key": f"{nest_two_key}"
                                    }, on_change=update_user_settings)
                                )
                            if nest_two_key == "interest_level":
                                nest_two_row.controls.append(
                                    ft.TextField(label="Interest Level", value=nest_two_val, width=100, data={
                                        "full_settings_key": f"settings_data[{option}][{nest_one_key}][{nest_two_key}]",
                                        "key": f"{nest_two_key}"
                                    }, on_change=update_user_settings)
                                )
                                
                        temp_cont_column.controls.append(nest_two_row)
                settings_column.controls.append(temp_cont_column)
        settings_page = settings_column
        page.add(settings_page)
    
    settings_icon = ft.Icon(name=ft.icons.SETTINGS, color=ft.colors.WHITE)
    settings_text = ft.Text(value="SETTINGS")
    settings_row = ft.Row(controls=[settings_icon,settings_text])
    settings_button = ft.ElevatedButton(content=settings_row, on_click=display_settings_page)



    #############################################################################
    #############################################################################
    #############################################################################
    # Stats Button 
    #FIXME No Stats page built yet
    stats_icon = ft.Icon(name=ft.icons.QUERY_STATS, color=ft.colors.WHITE)
    stats_text = ft.Text(value="STATS")
    stats_row = ft.Row(controls=[stats_icon,stats_text,under_construction_icon])
    stats_button = ft.ElevatedButton(content=stats_row, disabled=True)



    #############################################################################
    #############################################################################
    #############################################################################
    # Browse User Modules Button 
    #FIXME No module display page built yet
    browse_user_modules_icon = ft.Icon(name=ft.icons.BOOK, color=ft.colors.WHITE)
    browse_user_modules_text = ft.Text(value="BROWSE USER MODULES")
    browse_user_modules_row = ft.Row(controls=[browse_user_modules_icon,browse_user_modules_text,under_construction_icon])
    browse_user_modules_button = ft.ElevatedButton(content=browse_user_modules_row, disabled=True)

    # Browse Community modules Button 
    #FIXME no Module display page built yet
    #FIXME No community server built yet
    browse_community_modules_icon = ft.Icon(name=ft.icons.LAPTOP_CHROMEBOOK, color=ft.colors.WHITE)
    browse_community_modules_text = ft.Text(value="BROWSE COMMUNITY MODULES")
    browse_community_modules_row = ft.Row(controls=[browse_community_modules_icon, browse_community_modules_text,under_construction_icon])
    browse_community_modules_button = ft.ElevatedButton(content=browse_community_modules_row, disabled=True)

    # Edit Modules Button
    # FIXME No module display page built yet, no module editor designed yet
    # FIXME No edit question or add question functions built yet
    edit_modules_icon = ft.Icon(name=ft.icons.EDIT, color=ft.colors.WHITE)
    edit_modules_text = ft.Text(value="EDIT USER MODULES")
    edit_modules_row = ft.Row(controls=[edit_modules_icon,edit_modules_text,under_construction_icon])
    edit_modules_button = ft.ElevatedButton(content=edit_modules_row, disabled=True)

    # User Profile Button 
    #FIXME No User Profile backend designed yet
    #FIXME no user_profile display built yet
    user_profile_icon = ft.Icon(name=ft.icons.ACCOUNT_CIRCLE, color=ft.colors.WHITE)
    user_profile_text = ft.Text(value="MY PROFILE")
    user_profile_row = ft.Row(controls=[user_profile_icon,user_profile_text,under_construction_icon])
    user_profile_button = ft.ElevatedButton(content=user_profile_row, disabled=True)

    # Generate Questions
    #FIXME WIP, fix above things first, but give the users hope of incoming features
    ai_question_object_gen_icon = ft.Icon(name=ft.icons.SCIENCE, color=ft.colors.WHITE)
    ai_question_object_gen_text = ft.Text(value="AI Question Maker")
    ai_question_object_gen_row = ft.Row(controls=[ai_question_object_gen_icon,ai_question_object_gen_text,under_construction_icon])
    ai_question_object_gen_button = ft.ElevatedButton(content=ai_question_object_gen_row, disabled=True)

    ### Container Defines
    side_bar_content = ft.Column(height=page.height, width=(page.width / 2), controls=[
        menu_button,
        browse_user_modules_button,
        browse_community_modules_button,
        # edit_modules_button,
        stats_button,
        ai_question_object_gen_button,
        settings_button,
        user_profile_button,
        
        logout_button
        ])
    side_bar_container = ft.Container(content=side_bar_content, height=page.height)


    ### Page Defines

    ## Functions for Menu Bar

    ###################################################################################################################################################
    ###################################################################################################################################################
    ###################################################################################################################################################
    ###################################################################################################################################################
    ###################################################################################################################################################
    ###################################################################################################################################################
    ## Template Page #NOTE just copy paste this section for each page, seperated by six lines of #'s
    ### Icon Defines
    ### Element Defines





    ###################################################################################################################################################
    ###################################################################################################################################################
    ###################################################################################################################################################
    ###################################################################################################################################################
    ###################################################################################################################################################
    ###################################################################################################################################################

ft.app(main)
