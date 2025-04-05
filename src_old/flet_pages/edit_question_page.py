import flet as ft
import system_data
import os
from lib import helper
from datetime import datetime, date, timedelta
from flet_custom_containers import custom_controls
import firestore_db

class EditQuestionPage(ft.View):
    def __init__(
            self, page: ft.Page, questions_available_to_answer, 
            current_question,current_question_id,question_object_data,
            user_profile_data,CURRENT_USER,CURRENT_UUID,
            all_module_data) -> None:
        super().__init__()
        # CONSTRUCT THE PAGE
        # Assign passed globals to instance
        self.page                           = page
        self.page.theme_mode                = ft.ThemeMode.DARK
        self.questions_available_to_answer  = questions_available_to_answer
        self.all_module_data                = all_module_data
        self.current_question               = current_question
        self.current_question_id            = current_question_id
        if current_question_id == None or current_question_id == "":
            self.go_to_home_screen()
        self.question_object_data           = question_object_data
        self.user_profile_data              = user_profile_data
        self.CURRENT_USER                   = CURRENT_USER
        self.CURRENT_UUID                   = CURRENT_UUID

        ############################################################
        # Define General Data
        self.form_fields_width              = 300
        self.horizontal_alignment           = ft.CrossAxisAlignment.CENTER
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

        self.primary_subject                = custom_controls.PrimarySubjectField(    
            self.question_object_data,
            self.form_fields_width,
            self.current_question_id
        )

        self.module_name                    = custom_controls.ModuleNameField(
            self.question_object_data,
            self.form_fields_width,
            self.all_module_data,
            self.current_question_id
        )

        self.related_subjects               = custom_controls.RelatedSubjectsField(
            self.question_object_data,
            self.form_fields_width,
            self.current_question_id
        )

        self.related_concepts               = custom_controls.RelatedConceptsField(
            self.question_object_data,
            self.form_fields_width,
            self.current_question_id
        )

        self.question_entry                 = custom_controls.QuestionEntryField(
            self.page,
            self.question_object_data,
            self.form_fields_width,
            self.current_question_id
        )
        self.question_entry.padding = 5

        self.answer_entry                   = custom_controls.AnswerEntryField(
            self.page,
            self.question_object_data,
            self.form_fields_width,
            self.current_question_id
        )
        self.answer_entry.padding   = 5

        self.submit_edits_button             = ft.ElevatedButton(
            text        = "Submit Changes",
            on_click    = lambda e: self.submit_changes_to_question()
        )
        ############################################################
        # Define Composite Components -> ft.Container buttons

        ############################################################
        # Define Container elements for organization


        self.header_row = ft.Row(
            alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
            controls=[
                self.menu_button,
                self.exit_button
            ],
            width = self.form_fields_width
        )
        ############################################################
        # Piece it all together with self.controls
        self.controls=[
            self.header_row,
            self.primary_subject,
            self.module_name,
            self.related_subjects,
            self.related_concepts,
            self.question_entry,
            self.answer_entry,
            self.submit_edits_button]
        print(self.primary_subject.submission)
        print(self.module_name.submission)
        print(self.related_subjects.submission)
        print(self.related_concepts.submission)
        print(self.question_entry.text_submission)
        print(self.question_entry.image_submission)
        print(self.answer_entry.text_submission)
        print(self.answer_entry.image_submission)
        self.scroll = ft.ScrollMode.AUTO


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

    def go_to_display_modules_page          (self, e: ft.ControlEvent = None):
        self.page.go("/DisplayModulePage")
    
    def go_to_ai_question_generator_page    (self, e: ft.ControlEvent = None):
        self.page.go("/AIQuestionGeneratorPage")

    def submit_changes_to_question          (self, e: ft.ControlEvent = None):
        '''
        Give a printout to the console of all the question object fields
        directly changes that question objects fields inside question_object_data
        updates the question_object_data object, which will also be returned to whichever page you go to next
        No safeguards will exist here, besides those that restrict what can be entered into the form fields
        Once the update is complete, returns the user to the home page
        '''
        self.submit_edits_button.disabled = True # No double submit
        self.submit_edits_button.text = "Submitting Changes, please wait. . ."
        print("Submission Details:")
        print("Primary Subject: ",  self.primary_subject.submission)
        self.question_object_data[self.current_question_id]["primary_subject"]  = self.primary_subject.submission.lower()
        print("Module Name:     ",  self.module_name.submission)
        self.question_object_data[self.current_question_id]["module_name"]      = self.module_name.submission.lower()
        print("Related Subjects:",  self.related_subjects.submission)
        self.question_object_data[self.current_question_id]["subject"]          = self.related_subjects.submission
        print("Related Concepts:",  self.related_concepts.submission)
        self.question_object_data[self.current_question_id]["related"]          = self.related_concepts.submission
        print("Question Text:   ",  self.question_entry.text_submission)
        self.question_object_data[self.current_question_id]["question_text"]    = self.question_entry.text_submission
        print("Question Image:  ",  self.question_entry.image_submission)
        self.question_object_data[self.current_question_id]["question_image"]   = self.question_entry.image_submission
        print("Answer Text:     ",  self.answer_entry.text_submission)
        self.question_object_data[self.current_question_id]["answer_text"]      = self.answer_entry.text_submission
        print("Answer Image:    ",  self.answer_entry.image_submission)
        self.question_object_data[self.current_question_id]["answer_image"]     = self.answer_entry.image_submission

        # Ensure we submit the change to firestore db
        self.question_object_data[self.current_question_id] = firestore_db.update_question_in_firestore(self.current_question_id, self.question_object_data[self.current_question_id])
        system_data.update_question_object_data(self.question_object_data)

        self.all_module_data = system_data.get_all_module_data()


        media_files_input = set([])
        if self.question_entry.image_submission != None:
            media_files_input.add(self.question_entry.image_submission)
        if self.answer_entry.image_submission != None:
            media_files_input.add(self.answer_entry.image_submission)

        current_media_files = []
        uploading_files     = []
        for filename in os.listdir("system_data/media_files"):
            current_media_files.append(filename)
        for bullshit in os.listdir("uploads"):
            uploading_files = []
        

        for filename in media_files_input:
            if filename not in uploading_files and (filename in current_media_files):
                # Why wouldn't the given filename be in the uploads folder?
                # The file would not be in the uploads folder if were referencing a question that already has media attached
                #   In such cases the file would be found in the media_files/ directory
                continue # don't edit the file_name, since we haven't changed it
            if filename in current_media_files:
                index_val = filename.rfind(".")
                extension = filename[index_val:]
                file_no_ext = filename[:index_val]
                current_time = str(datetime.now())
                file_no_ext = current_time + self.CURRENT_UUID
                new_file_name = file_no_ext + extension
                # Change the name of the file in the question object
                if self.question_entry.image_submission == filename:
                    self.question_entry.image_submission = new_file_name
                if self.answer_entry.image_submission == filename:
                    self.answer_entry.image_submission = new_file_name
                # Change the name of the file itself
                try:           
                    os.rename(f"uploads/{filename}", (f"uploads/{new_file_name}"))
                except FileNotFoundError:
                    pass
                    # code failed because, submission of media did not change. Media is located in media_files not uploads
                    # In this case we should not rename the file_name


        files_to_move = set([])
        if self.question_entry.image_submission != None:
            files_to_move.add(self.question_entry.image_submission)
        if self.answer_entry.image_submission != None:
            files_to_move.add(self.answer_entry.image_submission)
        
        # Move and Clear the uploads folder after submission
        for filename in os.listdir("uploads"):
            if filename in files_to_move:
                helper.copy_file(f"uploads/{filename}", f"system_data/media_files/")
                firestore_db.write_media_file_to_firestore(filename)
                os.remove(f"uploads/{filename}")
        
        self.go_to_home_screen()
        