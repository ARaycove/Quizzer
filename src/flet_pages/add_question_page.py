import flet as ft
import system_data
import os
import firestore_db
from lib import helper
from datetime import datetime, date, timedelta
from flet_custom_containers import custom_controls

class AddQuestionPage(ft.View):
    def __init__(self, 
                 page: ft.Page, 
                 question_object_data,
                 user_profile_data,
                 CURRENT_USER,
                 CURRENT_UUID,
                 all_module_data
                 ) -> None:
        super().__init__()
        # CONSTRUCT THE PAGE
        # Assign passed globals to instance
        self.page                   = page
        self.page.theme_mode        = ft.ThemeMode.DARK
        self.CURRENT_USER           = CURRENT_USER
        self.CURRENT_UUID           = CURRENT_UUID
        self.user_profile_data      = user_profile_data
        self.question_object_data   = question_object_data
        self.all_module_data        = all_module_data
        self.subject_data           = system_data.get_subject_data()
        self.concept_data           = system_data.get_concept_data()
        ############################################################
        # Define General Data
        self.page.title             = "Quizzer - Add New Question"
        self.form_fields_width      = 300
        self.q_or_a                 = ""
        self.file_picker = ft.FilePicker(
            on_result=self.dialog_result,
            on_upload=self.upload_file)
        page.overlay.append(self.file_picker)
        page.update()
        # Form Data variables
        self.primary_subject_submission         = "miscellaneous" # misc by default, if a subject is Misc, then a backend function will go through and determine those
        self.module_name_submission             = None
        self.related_subjects_submission        = ["miscellaneous"]
        
        self.related_concepts_submission        = None
        self.question_text_submission           = None
        self.question_image_submission          = None
        self.question_audio_submission          = None
        self.question_video_submission          = None

        self.answer_text_submission             = None
        self.answer_image_submission            = None
        self.answer_audio_submission            = None
        self.answer_video_submission            = None
        ############################################################
        # Define Icons
        self.menu_icon      = ft.Icon(
            name    = ft.Icons.MENU_SHARP, 
            color   = ft.Colors.BLACK)
############################################################
        # Form elements from left to right, top to bottom
        self.menu_button                            = ft.ElevatedButton(
            content=self.menu_icon, 
            bgcolor="white", 
            on_click=self.go_to_menu_page)
        
        self.page_header_text                       = ft.Text(
            value="Add New Question",
            expand=True,
            text_align="center",
            size=36)

        self.exit_button                            = ft.IconButton(
            icon=ft.Icons.ARROW_BACK,
            icon_color=ft.Colors.BLACK,
            bgcolor=ft.Colors.WHITE,
            on_click=self.go_to_home_screen
        )
############################################################
############################################################
############################################################
        # Submission Row       
        self.submit_button                                  = ft.IconButton(
            icon        = ft.Icons.UPLOAD, 
            icon_color  = ft.Colors.BLACK,
            bgcolor     = ft.Colors.WHITE,
            tooltip     = "Submit the current question, \nThe question will be added to your account",
            on_click    = lambda e: self.submit_question(e))
        self.clear_form_button                              = ft.IconButton(
            icon        = ft.Icons.FORMAT_CLEAR,
            icon_color  = ft.Colors.BLACK,
            bgcolor     = ft.Colors.WHITE,
            tooltip     = "Clear all form fields and start over",
            on_click    = lambda e: self.clear_form_fields(e)
            )

        self.header_row                 = ft.Row(
            controls=[
                self.menu_button,
                self.page_header_text,
                self.exit_button
            ],
            alignment           =ft.MainAxisAlignment.SPACE_BETWEEN
        )    

        self.primary_subject_entry_box  = custom_controls.PrimarySubjectField(self.question_object_data, self.form_fields_width)
        self.module_name_entry_box      = custom_controls.ModuleNameField(self.question_object_data,self.form_fields_width,self.all_module_data)
        self.related_subjects_entry_box = custom_controls.RelatedSubjectsField(self.question_object_data, self.form_fields_width)
        self.related_concepts_entry_box  = custom_controls.RelatedConceptsField(self.question_object_data, self.form_fields_width)
        self.question_entry_box         = custom_controls.QuestionEntryField(self.page, self.question_object_data, self.form_fields_width)
        self.answer_entry_box           = custom_controls.AnswerEntryField(self.page, self.question_object_data, self.form_fields_width)


        self.submission_row             = ft.Row(
            controls=[
                self.submit_button,
                self.clear_form_button
            ],
            alignment=ft.MainAxisAlignment.CENTER
        )

        ############################################################
        # Piece it all together with self.controls
        self.controls=[
            self.header_row,
            self.primary_subject_entry_box,
            self.module_name_entry_box,
            self.related_subjects_entry_box,
            self.related_concepts_entry_box,
            self.question_entry_box,
            self.answer_entry_box,
            self.submission_row
        ]
        self.scroll                 = ft.ScrollMode.HIDDEN
        self.horizontal_alignment   = ft.CrossAxisAlignment.CENTER


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
############################
# File upload utility functions
    def upload_file(self, e):
        upload_list = []
        if self.file_picker.result != None and self.file_picker.result.files != None:
            for f in self.file_picker.result.files:
                upload_list.append(
                    ft.FilePickerUploadFile(f.name, upload_url=self.page.get_upload_url(f.name, 600))
                )
            self.file_picker.upload(upload_list)
    def dialog_result(self, e: ft.FilePickerResultEvent):
        # Construct the file path, and put the to-be uploaded file in staging area
        print(self.file_picker.result.files[0].path)
        if self.file_picker.result.files[0].path != None: # for desktop version
            helper.copy_file(self.file_picker.result.files[0].path, "uploads")
        else: # for web apps
            self.upload_file(e)
        file_path = f"uploads/{self.file_picker.result.files[0].name}"
        # Determine mime type
        media_type = helper.detect_media_type(file_path)
        if media_type.startswith("image"):
            media_type="image"
        elif media_type.startswith("audio"):
            media_type="audio"
        elif media_type.startswith("video"):
            media_type="video"
        else:
            media_type="other"
            return # if other we exit the dialog
        # assign file_path to appropriate question or answer media file
        #   Will later be used by the actual upload_question button to move the media into the system_data/media_files dir -> media_file_name may need to be updated when adding to the main database
        #   when exiting this interface, we should clear the uploads folder
        if self.q_or_a == "question_media":
            print("Question being uploaded")
            if media_type == "image":
                self.update_question_image(self.file_picker.result.files[0].name)
                self.question_preview_image.src = file_path
                self.question_preview_image.height = 100
                self.question_image.icon_color = ft.Colors.GREEN
            elif media_type == "audio":
                # Audio not currently supported
                pass #FIXME
                # question_audio.data = file_path
                # question_preview_audio.src = file_path
                # question_preview_audio.autoplay=True
                # question_preview_audio.volume = 1
                # question_audio.icon_color = ft.Colors.GREEN
            elif media_type == "video":
                # Video not currently supported
                pass #FIXME
                # question_video.data = file_path
                # question_video.icon_color = ft.Colors.GREEN
        elif self.q_or_a =="answer_media":
            print("Answer being uploaded")
            if media_type == "image":
                self.update_answer_image(self.file_picker.result.files[0].name)
                self.answer_preview_image.src = file_path
                self.answer_preview_image.height = 100
                self.answer_image.icon_color = ft.Colors.GREEN
            elif media_type == "audio":
                # Audio not currently supported
                pass #FIXME
                # answer_audio.data = file_path
                # answer_audio.icon_color = ft.colors.GREEN
            elif media_type == "video":
                # Video not currently supported
                pass #FIXME
                # answer_video.data = file_path
                # answer_video.icon_color = ft.colors.GREEN

        self.page.update()

    def upload_media(self,status):
        self.file_picker.pick_files()
        self.page.update()
        self.q_or_a = status
############################

################
# Submission Button functions
    def clear_form_fields(self, e = None):
        self.primary_subject_entry_box  = custom_controls.PrimarySubjectField(self.question_object_data, self.form_fields_width)
        self.module_name_entry_box      = custom_controls.ModuleNameField(self.question_object_data,self.form_fields_width,self.all_module_data)
        self.related_subjects_entry_box = custom_controls.RelatedSubjectsField(self.question_object_data, self.form_fields_width)
        self.related_concepts_entry_box  = custom_controls.RelatedConceptsField(self.question_object_data, self.form_fields_width)
        self.question_entry_box         = custom_controls.QuestionEntryField(self.page, self.question_object_data, self.form_fields_width)
        self.answer_entry_box           = custom_controls.AnswerEntryField(self.page, self.question_object_data, self.form_fields_width)
        self.controls=[
            self.header_row,
            self.primary_subject_entry_box,
            self.module_name_entry_box,
            self.related_subjects_entry_box,
            self.related_concepts_entry_box,
            self.question_entry_box,
            self.answer_entry_box,
            self.submission_row
        ]
        self.scroll                 = ft.ScrollMode.HIDDEN
        self.horizontal_alignment   = ft.CrossAxisAlignment.CENTER
        self.page.update()
        

    def submit_question(self, e):
        self.primary_subject_submission     = self.primary_subject_entry_box.submission.lower()
        self.module_name_submission         = self.module_name_entry_box.submission.lower()
        self.related_subjects_submission    = self.related_subjects_entry_box.submission
        if self.related_subjects_submission == None:
            self.related_concepts_submission = ["miscellaneous"]
        self.related_concepts_submission    = self.related_concepts_entry_box.submission
        self.question_text_submission       = self.question_entry_box.text_submission
        self.question_image_submission      = self.question_entry_box.image_submission
        self.question_audio_submission      = self.question_entry_box.audio_submission
        self.question_video_submission      = self.question_entry_box.video_submission
        self.answer_text_submission         = self.answer_entry_box.text_submission
        self.answer_image_submission        = self.answer_entry_box.image_submission
        self.answer_audio_submission        = self.answer_entry_box.audio_submission
        self.answer_video_submission        = self.answer_entry_box.video_submission
        print(f"self.primary_subject_submission has value of    : {self.primary_subject_submission} of type {type(self.primary_subject_submission)}")
        print(f"self.module_name_submission has value of        : {self.module_name_submission} of type {type(self.module_name_submission)}")
        print(f"self.related_subjects_submission has value of   : {self.related_subjects_submission} of type {type(self.related_subjects_submission)}")
        print(f"self.related_concepts_submission has value of   : {self.related_concepts_submission} of type {type(self.related_concepts_submission)}")
        print(f"self.question_text_submission has value of      : {self.question_text_submission} of type {type(self.question_text_submission)}")
        print(f"self.question_image_submission has value of     : {self.question_image_submission} of type {type(self.question_image_submission)}")
        print(f"self.question_audio_submission has value of     : {self.question_audio_submission} of type {type(self.question_audio_submission)}")
        print(f"self.question_video_submission has value of     : {self.question_video_submission} of type {type(self.question_video_submission)}")
        print(f"self.answer_text_submission has value of        : {self.answer_text_submission} of type {type(self.answer_text_submission)}")
        print(f"self.answer_image_submission has value of       : {self.answer_image_submission} of type {type(self.answer_image_submission)}")
        print(f"self.answer_audio_submission has value of       : {self.answer_audio_submission} of type {type(self.answer_audio_submission)}")
        print(f"self.answer_video_submission has value of       : {self.answer_video_submission} of type {type(self.answer_video_submission)}")
        media_files_input = set([])
        if self.question_image_submission != None:
            media_files_input.add(self.question_image_submission)
        if self.question_audio_submission != None:
            media_files_input.add(self.question_audio_submission)
        if self.question_video_submission != None:
            media_files_input.add(self.question_video_submission)
        if self.answer_image_submission != None:
            media_files_input.add(self.answer_image_submission)
        if self.answer_audio_submission != None:
            media_files_input.add(self.answer_audio_submission)
        if self.answer_video_submission != None:
            media_files_input.add(self.answer_video_submission)

        # Get a list of all media files that exist in the system data
        current_media_files = []
        for filename in os.listdir("system_data/media_files"):
            current_media_files.append(filename)
        
        for filename in media_files_input:
            if filename in current_media_files:
                print("GOTCHA")
                index_val = filename.rfind(".")
                extension = filename[index_val:]
                file_no_ext = filename[:index_val]
                current_time = str(datetime.now())
                file_no_ext = current_time + self.CURRENT_UUID
                new_file_name = file_no_ext + extension
                # Change the name of the file in the question object
                if self.question_image_submission == filename:
                    self.question_image_submission = new_file_name
                if self.question_audio_submission == filename:
                    self.question_audio_submission = new_file_name
                if self.question_video_submission == filename:
                    self.question_video_submission = new_file_name
                if self.answer_image_submission == filename:
                    self.answer_image_submission = new_file_name
                if self.answer_audio_submission == filename:
                    self.answer_audio_submission = new_file_name
                if self.answer_video_submission == filename:
                    self.answer_video_submission = new_file_name
                # Change the name of the file itself               
                os.rename(f"uploads/{filename}", (f"uploads/{new_file_name}"))
        if not isinstance(self.related_subjects_submission, list):
            self.related_subjects_submission == ["miscellaneous"]
        value = system_data.add_new_question_object(
            user_profile_data   = self.user_profile_data,
            question_object_data= self.question_object_data,
            all_module_data     = self.all_module_data,
            subject             = self.related_subjects_submission,                
            related             = self.related_concepts_submission,
            question_text       = self.question_text_submission,
            question_image      = self.question_image_submission,
            question_audio      = self.question_audio_submission,
            question_video      = self.question_video_submission,
            answer_text         = self.answer_text_submission,
            answer_image        = self.answer_image_submission,
            answer_audio        = self.answer_audio_submission,
            answer_video        = self.answer_video_submission,
            module_name         = self.module_name_submission
            )
        if value == None:
            print("Invalid Question entry")
            if self.module_name_submission == None:
                self.module_name_text.color = ft.Colors.RED
            return None
        
        # self.question_object_data   = value[0]
        # self.user_profile_data      = value[1]
        self.question_object_data = system_data.get_question_object_data()
        self.user_profile_data = system_data.get_user_data(self.CURRENT_USER)
        # If the question was valid, then we should move the media uploaded into the system_data/media_files dir
        files_to_move = set([])
        if self.question_image_submission != None:
            files_to_move.add(self.question_image_submission)
        if self.question_audio_submission != None:
            files_to_move.add(self.question_audio_submission)
        if self.question_video_submission != None:
            files_to_move.add(self.question_video_submission)
        if self.answer_image_submission != None:
            files_to_move.add(self.answer_image_submission)
        if self.answer_audio_submission != None:
            files_to_move.add(self.answer_audio_submission)
        if self.answer_video_submission != None:
            files_to_move.add(self.answer_video_submission)
        
        # Move and Clear the uploads folder after submission
        for filename in os.listdir("uploads"):
            if filename in files_to_move:
                helper.copy_file(f"uploads/{filename}", f"system_data/media_files/")
                # firestore_db.write_media_file_to_firestore(filename)
                os.remove(f"uploads/{filename}")

        
        system_data.update_question_object_data(self.question_object_data)
        self.all_module_data = system_data.get_all_module_data()
        self.concept_data = system_data.get_concept_data()
        self.clear_form_fields()