import flet as ft
from lib import helper
from datetime import date
import system_data
import os
import time
import sys
import asyncio
print(ft.__file__)

# PAGES
from flet_pages.login_page              import LoginPage
from flet_pages.new_profile_page        import NewProfilePage
from flet_pages.home_page               import HomePage
from flet_pages.menu_page               import MenuPage
from flet_pages.add_question_page       import AddQuestionPage
from flet_pages.edit_question_page      import EditQuestionPage
from flet_pages.display_modules_page    import DisplayModulePage
from flet_pages.settings_page           import SettingsPage
from flet_pages.feedback_page           import FeedbackPage
from flet_pages.stats_page              import StatsPage
import platform

arch = platform.machine()
if arch in ["arm64", "aarch64"]:
    arch_path = "arm64-v8a"
elif arch == "armv7l":
    arch_path = "armeabi-v7a"
elif arch == "x86_64":
    arch_path = "x86_64"
elif arch == "i686":
    arch_path = "x86"
else:
    raise RuntimeError(f"Unsupported architecture: {arch}")
print(f"The Architecture of the device is: {arch}")
# Globals
print("sys.path:", sys.path)
os.environ["FLET_SECRET_KEY"] = os.urandom(12).hex()
CURRENT_USER = ""
CURRENT_UUID = ""
# Example code from Google 
# bucket = storage_client.bucket("your-bucket-name")
# blob = bucket.blob(f"system_data/user_profiles/{CURRENT_USER}/{CURRENT_USER}_data.json")
# blob.upload_from_filename(f"data/system_data/user_profiles/{CURRENT_USER}/{CURRENT_USER}_data.json")
# GLOBAL VARIABLES
print(f"Initializing Globals Into Memory")
print(f"Globals are currently blank, further assignment is needed")
current_question        = {}
current_question_id     = ""
user_profile_data       = {}
question_object_data    = system_data.get_question_object_data()
system_data.update_question_object_data(question_object_data) # Regenerates the all_modules block, subject and concept blocks too
all_module_data         = system_data.get_all_module_data()
current_page_data       = ""
pages_visited           = [] # When a new route is detected we append the link to this variable

# GLOBAL SWITCHES
currently_displayed = "question"
# Has the user seen the answer to the question?
has_seen = False
# Determines what we do with the menu when the button is clicked
menu_active = False
# Do we have any available questions to answer?
questions_available_to_answer = False


def main(page: ft.Page):
    page.theme_mode = ft.ThemeMode.DARK
    print("Entered def main")
    async def change_view(e):
        global pages_visited
        global current_page_data
        global current_question_id
        global user_profile_data
        pages_visited.append(page.route)
        print(pages_visited)
        # print(f"Received change in route, {page.route}")
        await update_globals(current_page_data)
        # print("Current question id:",current_question_id)
        page.views.clear()
        next_display = ""
        if page.route == "/LoginPage":
            next_display = LoginPage(
                page, 
                questions_available_to_answer, 
                question_object_data,
                user_profile_data,
                CURRENT_USER,
                CURRENT_UUID,
                pages_visited,
                )
        elif page.route == "/NewProfilePage":
            print("Going to New Profile Page")
            next_display = NewProfilePage(
                page,
                question_object_data,
                )
        elif page.route == "/HomePage":
            print("Going to Home Page -> Main Quizzer Interface")
            # print("This is the user_profile_data object being fed in",user_profile_data.keys())
            # print("Current User", CURRENT_USER)
            # print(user_profile_data)
            if user_profile_data == {}:
                print("Dictionary is empty for some reason")
                user_profile_data = system_data.get_user_data(CURRENT_USER)
                # print(user_profile_data)
            next_display = HomePage(
                                    page,
                                    questions_available_to_answer,
                                    current_question,
                                    current_question_id,
                                    question_object_data,
                                    user_profile_data,
                                    CURRENT_USER,
                                    CURRENT_UUID,
                                    currently_displayed,
                                    has_seen,
                                    pages_visited,
                                )
        elif page.route == "/Menu":
            print("Going to menu page")
            next_display = MenuPage(page,
                                    pages_visited,
                                    )
        elif page.route == "/AddQuestionPage": #FIXME
            print("Going to Add Question Page")
            next_display = AddQuestionPage(page, 
                                           question_object_data,
                                           user_profile_data,
                                           CURRENT_USER,
                                           CURRENT_UUID,
                                           all_module_data,
                                           )
        elif page.route == "/EditQuestionPage": #FIXME
            print("Going to Edit Question Page") 
            next_display = EditQuestionPage(page,
                                            questions_available_to_answer,
                                            current_question,
                                            current_question_id,
                                            question_object_data,
                                            user_profile_data,
                                            CURRENT_USER,
                                            CURRENT_UUID,
                                            all_module_data,
                                            )        
        elif page.route == "/DisplayModulePage": #FIXME
            print("Going to User Modules Page") # This page shows every module that is currently enabled by the user
            next_display = DisplayModulePage(page,
                                             user_profile_data,
                                             all_module_data,
                                             question_object_data
                                             )
        elif page.route == "/StatsPage": #FIXME
            print("Going to Stats Page")
        # Plot Stats Relating to user performance
            answered    = user_profile_data["stats"]["questions_answered_by_date"]
            target      = user_profile_data["settings"]["desired_daily_questions"]
            await system_data.plot_x_over_time(answered, target)
            next_display = StatsPage(page,
                                     user_profile_data,
                                     CURRENT_USER,
                                     CURRENT_UUID)


        elif page.route == "/AIQuestionGeneratorPage": #FIXME
            print("Going to AI Question Generator Page")
            next_display = ft.View()


        elif page.route == "/SettingPage": #FIXME
            print("Going to Settings Page")
            next_display = SettingsPage(page,
                                        questions_available_to_answer,
                                        current_question,
                                        current_question_id,
                                        question_object_data,
                                        user_profile_data,
                                        CURRENT_USER,
                                        CURRENT_UUID,
                                        )


        elif page.route == "/UserProfilePage": #FIXME
            print("Going to User Profile Page")
            next_display = ft.View()

        elif page.route == "/FeedbackPage": 
            print("Going to Feedback Page")
            next_display = FeedbackPage(page,
                                        pages_visited)
        current_page_data = next_display
        page.views.append(
            # Pass in the page and any globals it might need to work
            next_display
        )
        page.update()

    # When the route variable changes we call the router function
    page.on_route_change = change_view
    async def update_globals(current_page_data):
        if current_page_data == "": # If we just opened, it will be an empty string, nothing to update
            return None
        # Load in all the globals we use:
        global questions_available_to_answer    # In List
        global current_question                 # In List
        global current_question_id              # In List
        global question_object_data             # In List
        global user_profile_data                # In List
        global CURRENT_USER                     # In List
        global CURRENT_UUID                     # In List
        global currently_displayed              # In List
        global has_seen                         # In List
        global all_module_data                  # In List
        # for key in vars(current_page_data).keys():
        #     print(key)
        # Error Handling while updating each one, if the page didn't use the global then we will get an Attribute Error
        try:
            questions_available_to_answer = current_page_data.questions_available_to_answer
            print("    Questions Available to Answer Updated")
        except AttributeError as e:
            pass

        try:
            current_question = current_page_data.current_question
            print("    Current Question Updated")
        except AttributeError as e:
            pass

        try:
            current_question_id = current_page_data.current_question_id
            print("    Current Question ID Updated")
            # print(f"    {current_question_id}")
        except AttributeError as e:
            pass

        try:
            question_object_data = current_page_data.question_object_data
            print("    Question Object Data Updated")
        except AttributeError as e:
            pass

        try:
            user_profile_data = current_page_data.user_profile_data
            print("    User Profile Data Updated")
            # print(f"    {current_page_data.user_profile_data}")
        except AttributeError as e:
            pass

        try:
            CURRENT_USER = current_page_data.CURRENT_USER
            print("    Current User Updated")
            # print(f"    {CURRENT_USER}")
        except AttributeError as e:
            pass

        try:
            CURRENT_UUID = current_page_data.CURRENT_UUID
            print("    Current UUID Updated")
            # print(f"    {CURRENT_UUID}")
        except AttributeError as e:
            pass

        try:
            currently_displayed = current_page_data.currently_displayed
            print("    Currently_Displayed updated")
        except AttributeError as e:
            pass

        try:
            has_seen = current_page_data.has_seen
            # print("    Has_Seen updated")
        except AttributeError as e:
            pass

        try:
            all_module_data = current_page_data.all_module_data
            # print("    All Module_data Updated")
        except AttributeError as e:
            pass
        

    # Initial State

    page.go("/LoginPage")
    print(page.route)
ft.app(target=main, upload_dir="uploads")