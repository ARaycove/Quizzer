import flet as ft
import system_data
import os
from lib import helper
from datetime import datetime, date, timedelta

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
        self.text_input_width       = 300
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
            name    = ft.icons.MENU_SHARP, 
            color   = ft.colors.BLACK)
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
            icon=ft.icons.ARROW_BACK,
            icon_color=ft.colors.BLACK,
            bgcolor=ft.colors.WHITE,
            on_click=self.go_to_home_screen
        )
############################################################
############################################################
############################################################
        # Primary Subject Field
        self.primary_subject_text                   = ft.Text(
            value   = "Primary Subject", 
            size    = 24,
            tooltip = "What is the Primary Subject, or Field of Study, of this question?\n For example is this a biology question, anatomy, mathematics, calculus, history, etc.")
        
        self.primary_subject_textfield              = ft.TextField(
            width=self.form_fields_width,
            on_change=lambda e: self.update_primary_subject(e.data)
            )
        
        self.primary_subject_back_button            = ft.IconButton(
            icon=ft.icons.ARROW_BACK, 
            icon_color=ft.colors.BLACK, 
            tooltip="Select from from list", 
            bgcolor=ft.colors.WHITE, 
            on_click=self.show_primary_subject_autocomplete_option)
        
        self.add_new_primary_subject_button         = ft.IconButton(
            icon=ft.icons.ADD, 
            icon_color=ft.colors.BLACK, 
            tooltip="Add a subject that isn't in the list", 
            bgcolor=ft.colors.WHITE, 
            on_click=self.show_primary_subject_textfield_option)
        
        self.primary_subject_input                  = ft.AutoComplete(
            suggestions=[ft.AutoCompleteSuggestion(key=i, value=i) for i in self.subject_data.keys()],
            on_select=lambda e: self.update_primary_subject(e.selection.value))
        
        self.primary_subject_textfield_option       = ft.Row(
            controls=[
                self.primary_subject_textfield, 
                self.primary_subject_back_button])
        
        self.primary_subject_autocomplete_option    = ft.Row(
            controls=[ft.Column(
                controls=[
                    ft.Stack(
                        controls=[self.primary_subject_input],
                        width=self.form_fields_width), 
                    self.add_new_primary_subject_button], 
                height=75, 
                wrap=True)])      
        

############################################################
############################################################
############################################################
        # Module Name Field
        self.module_name_text                       = ft.Text(
            value   ="Define the Module:", 
            size    =24, 
            tooltip ="What module does the question belong to?\n Begin by typing the name of the module, you'll be given a list of suggestions based on what modules already exist by that name\n You can contribute to any module \n BE AWARE: adding a question to a pre-existing module, will import that module into your profile\n Please Avoid adding duplicate questions to a module")
        
        self.module_name_textfield                  = ft.TextField(
            width=self.form_fields_width,
            on_submit=lambda e: self.update_module_name(e.data))
        
        self.module_name_back_button                = ft.IconButton(
            icon=ft.icons.ARROW_BACK, 
            icon_color=ft.colors.BLACK, 
            tooltip="Add a subject that isn't in the list", 
            bgcolor=ft.colors.WHITE, 
            on_click=self.show_module_name_autocomplete_option)
        
        self.add_new_module_button                  = ft.IconButton(
            icon=ft.icons.ADD, 
            icon_color=ft.colors.BLACK, 
            tooltip="Add a subject that isn't in the list", 
            bgcolor=ft.colors.WHITE, 
            on_click=self.show_module_name_textfield_option) 

        self.module_name_input                      = ft.AutoComplete(
            suggestions=[ft.AutoCompleteSuggestion(key=i, value=i) for i in self.all_module_data.keys()],
            on_select=lambda e: self.update_module_name(e.selection.value))

        self.module_name_textfield_option           = ft.Row(
            controls=[
                self.module_name_textfield, 
                self.module_name_back_button])
        
        self.module_name_autocomplete_option        = ft.Row(
            controls=[ft.Column(
                controls=[
                    ft.Stack(
                        controls=[self.module_name_input],
                        width=self.form_fields_width), 
                    self.add_new_module_button], 
                height=75, 
                wrap=True)])


############################################################
############################################################
############################################################
        # Related Subjects Field
        self.related_subjects_textfield             = ft.TextField(
            width=self.form_fields_width, 
            on_submit=lambda e: self.add_to_related_subjects(e, self.related_subjects_textfield.value))
        
        self.related_subjects_display               = ft.TextField(
            label="Related Subjects",
            tooltip="What other subjects relate to this question?\n For example it might be a calculus question, but calculus also falls under mathematics, \nThe question may also be referrencing a historical event, thus related to history as well",
            multiline=True, 
            disabled=True, 
            width=self.form_fields_width)
        
        self.clear_related_subject_display_button           = ft.IconButton(
            icon=ft.icons.CLEAR, 
            icon_color=ft.colors.BLACK, 
            tooltip="Clear The Related Subjects Input Field", 
            bgcolor=ft.colors.WHITE, 
            on_click=self.clear_related_subjects_field)
        
        self.related_subjects_back_button                   = ft.IconButton(
            icon=ft.icons.ARROW_BACK, 
            icon_color=ft.colors.BLACK, 
            tooltip="Clear The Related Subjects Input Field", 
            bgcolor=ft.colors.WHITE, 
            on_click=self.show_related_subject_autocomplete_option)
        
        self.add_new_related_subject_button                 = ft.IconButton(
            icon=ft.icons.ADD, 
            icon_color=ft.colors.BLACK, 
            tooltip="Add a subject that isn't in the list", 
            bgcolor=ft.colors.WHITE, 
            on_click=self.show_related_subject_textfield_option)
        
        self.related_subjects_autocomplete_input    = ft.AutoComplete(
            suggestions=[ft.AutoCompleteSuggestion(key=i, value=i) for i in self.subject_data.keys()],
            on_select=lambda e: self.add_to_related_subjects(e, e.selection.value))
        
        self.related_subjects_display_row = ft.Row(
            controls=[
                self.related_subjects_display, 
                self.clear_related_subject_display_button])
        
        self.related_subjects_autocomplete_option   = ft.Row(
            controls=[
                ft.Column(
                    controls=[
                        ft.Stack(
                            controls=[self.related_subjects_autocomplete_input],
                            width=self.form_fields_width), 
                        self.add_new_related_subject_button], 
                    height=75, 
                    wrap=True)])
        
        self.related_subjects_textfield_option      = ft.Row(
            controls=[
                self.related_subjects_textfield, 
                self.related_subjects_back_button])

############################################################
############################################################
############################################################
        # Related Concepts Field
        self.related_concepts_textfield             = ft.TextField(
            width=self.form_fields_width, 
            on_submit=lambda e: self.add_to_related_concepts(e, self.related_concepts_textfield.value))
        
        self.related_concepts = ft.TextField(
            label="Related Concepts and Terms",           
            tooltip="What concepts and terms are related to this question?\nFor example the question What year was xyz invented and who invented it? points to the term xyz, to the historical period, and to the individual\n",
            multiline=True, 
            disabled=True, 
            width=self.form_fields_width)
        
        self.related_concepts_back_button                   = ft.IconButton(
            icon=ft.icons.ARROW_BACK, 
            icon_color=ft.colors.BLACK, 
            tooltip="Clear the Related Concepts Input Field", 
            bgcolor=ft.colors.WHITE, 
            on_click=self.show_related_concepts_autocomplete_option)
        
        self.clear_related_button                           = ft.IconButton(
            icon=ft.icons.CLEAR, 
            icon_color=ft.colors.BLACK, 
            tooltip="Clear the Related Concepts Input Field", 
            bgcolor=ft.colors.WHITE, 
            on_click=self.clear_related_concepts_field)
        
        self.add_new_concept_button                         = ft.IconButton(
            icon=ft.icons.ADD, 
            icon_color=ft.colors.BLACK, 
            tooltip="Add a concept that isn't in the list", 
            bgcolor=ft.colors.WHITE, 
            on_click=self.show_related_concepts_textfield_option)
        
        self.concept_auto_complete                       = ft.AutoComplete(
            suggestions=[ft.AutoCompleteSuggestion(key=i, value=i) for i in self.concept_data.keys()],
            on_select=lambda e: self.add_to_related_concepts(e, e.selection.value))
        
        self.related_concepts_display_row           = ft.Row(
            controls=[
                self.related_concepts, 
                self.clear_related_button])
        
        self.related_concepts_autocomplete_option   = ft.Row(
            controls=[
                ft.Column(
                    controls=[
                        ft.Stack(
                            controls=[self.concept_auto_complete],
                            width=self.form_fields_width), 
                        self.add_new_concept_button], 
                    height=75, 
                    wrap=True)])
        self.related_concepts_textfield_option      = ft.Row(
            controls=[
                self.related_concepts_textfield, 
                self.related_concepts_back_button])
############################################################
############################################################
############################################################
        # Question value Fields
        self.question_text                          = ft.TextField(
            label="Question Text",
            multiline=True, 
            tooltip="What's the Question?", 
            expand=True,
            on_change=lambda e: self.update_question_text(e.data))
        
        self.question_preview_image = ft.Image()
        
        self.question_preview_audio = ft.Text(
            value="Audio not currently supported")
        
        self.question_preview_video = ft.Text(
            value="Video not currently supported")
        
        self.question_image                                 = ft.IconButton(
            icon=ft.icons.IMAGE, 
            icon_color=ft.colors.RED, 
            data="")
        
        self.question_audio                                 = ft.IconButton(
            icon=ft.icons.AUDIO_FILE, 
            icon_color=ft.colors.RED, 
            data="")
        
        self.question_video                                 = ft.IconButton(
            icon=ft.icons.VIDEO_FILE, 
            icon_color=ft.colors.RED, 
            data="")
        
        self.question_media_upload_button           = ft.ElevatedButton(
            text="Upload Question Media", 
            tooltip="Quizzer will automatically detect whether the media you upload is an image, audio, or video file,\n Alternatively you can drag and drop the media into the interface\nRED indicates no media for that type (image, audio, video)\n GREEN indicates you've added that type of media to the question",
            data="question_media", 
            on_click=lambda _: self.upload_media(self.question_media_upload_button.data))
############################################################
############################################################
############################################################
        # Answer value Fields       
        self.answer_text                            = ft.TextField(
            label="Answer Text", 
            multiline=True, 
            tooltip="What's the Answer?", 
            expand=True,
            on_change=lambda e: self.update_answer_text(e.data))
        self.answer_preview_audio   = ft.Text()

        self.answer_preview_image   = ft.Image()

        self.answer_preview_video = ft.Text()

        self.answer_image                                   = ft.IconButton(
            icon=ft.icons.IMAGE, 
            on_click=lambda e: print(e), 
            icon_color=ft.colors.RED,
            data="")
        
        self.answer_audio                                   = ft.IconButton(
            icon=ft.icons.AUDIO_FILE, 
            on_click=lambda e: print(e), 
            icon_color=ft.colors.RED,
            data="")
        
        self.answer_video                                   = ft.IconButton(
            icon=ft.icons.VIDEO_FILE, 
            on_click=lambda e: print(e), 
            icon_color=ft.colors.RED,
            data="")
        
        self.answer_media_upload_button                     = ft.ElevatedButton(
            text="Upload Answer Media", 
            tooltip="Quizzer will automatically detect whether the media you upload is an image, audio, or video file\n Alternatively you can drag and drop the media into the interface\nRED indicates no media for that type (image, audio, video)\n GREEN indicates you've added that type of media to the question",
            data="answer_media", 
            on_click=lambda _: self.upload_media(self.answer_media_upload_button.data))
############################################################
############################################################
############################################################
        # Submission Row       
        self.submit_button                                  = ft.IconButton(
            icon        = ft.icons.UPLOAD, 
            icon_color  = ft.colors.BLACK,
            bgcolor     = ft.colors.WHITE,
            tooltip     = "Submit the current question, \nThe question will be added to your account",
            on_click    = lambda e: self.submit_question(e))
        self.clear_form_button                              = ft.IconButton(
            icon        = ft.icons.FORMAT_CLEAR,
            icon_color  = ft.colors.BLACK,
            bgcolor     = ft.colors.WHITE,
            tooltip     = "Clear all form fields and start over",
            on_click    = lambda e: self.clear_form_fields(e)
            )

        ############################################################
        # Form is divided by:
        #   Header
        #   Middle Scrollable Form
        #   Submission and Cancel Button
        # Define Container elements for organization
        self.header_row                 = ft.Row(
            controls=[
                self.menu_button,
                self.page_header_text,
                self.exit_button
            ],
            alignment           =ft.MainAxisAlignment.SPACE_BETWEEN
        )
        self.left_side_column           = ft.Column(
            alignment           =ft.MainAxisAlignment.START,
            horizontal_alignment=ft.CrossAxisAlignment.START,
            controls=[
                self.primary_subject_text,
                self.primary_subject_autocomplete_option,
                self.related_subjects_display_row,
                self.related_subjects_autocomplete_option
            ]
        )

        self.right_side_column          = ft.Column(
            alignment           =ft.MainAxisAlignment.START,
            horizontal_alignment=ft.CrossAxisAlignment.START,
            controls=[
                self.module_name_text,
                self.module_name_autocomplete_option,
                self.related_concepts_display_row,
                self.related_concepts_autocomplete_option
            ]
        )        

        self.form_fields                = ft.Row(
            alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
            controls=[self.left_side_column,self.right_side_column],
            wrap=True
        )
        if self.page.width >= 2 * self.form_fields_width:
            self.form_fields.wrap = False

        self.question_media_status      = ft.Row(
            alignment=ft.MainAxisAlignment.SPACE_AROUND,
            controls=[
                self.question_image,
                self.question_audio,
                self.question_video
            ]
        )

        self.answer_media_status        = ft.Row(
            alignment=ft.MainAxisAlignment.SPACE_AROUND,
            controls = [
                self.answer_image,
                self.answer_audio,
                self.answer_video
            ]
        )

        self.question_entry_box         = ft.Column(
            controls=[
                self.question_text,
                self.question_preview_image,
                self.question_preview_audio,
                self.question_preview_video,
                self.question_media_status,
                self.question_media_upload_button
            ],
            horizontal_alignment=ft.CrossAxisAlignment.CENTER           
        )

        self.answer_entry_box           = ft.Column(
            controls=[
                self.answer_text,
                self.answer_preview_image,
                # self.answer_preview_audio,
                # self.answer_preview_video,
                self.answer_media_status,
                self.answer_media_upload_button
            ],
            horizontal_alignment=ft.CrossAxisAlignment.CENTER
        )

        self.add_question_column        = ft.Column(
            controls=[
                self.form_fields,
                self.question_entry_box,
                self.answer_entry_box
            ],
            on_scroll=ft.ScrollMode.ALWAYS,
            alignment=ft.MainAxisAlignment.START,
        )

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
            self.add_question_column,
            self.submission_row
        ]
        self.scroll = ft.ScrollMode.HIDDEN


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


    # These functions effect the displayed form elements
    def show_primary_subject_textfield_option       (self, e: ft.ControlEvent):
        del self.left_side_column.controls[1]
        self.left_side_column.controls.insert(1, self.primary_subject_textfield_option)
        self.primary_subject = "Miscellaneous"
        self.page.update()
    def show_primary_subject_autocomplete_option    (self, e:ft.ControlEvent):
        del self.left_side_column.controls[1]
        self.left_side_column.controls.insert(1, self.primary_subject_autocomplete_option)
        self.primary_subject = "Miscellaneous"
        self.page.update()



    def show_module_name_textfield_option           (self, e: ft.ControlEvent):
        del self.right_side_column.controls[1]
        self.right_side_column.controls.insert(1, self.module_name_textfield_option)
        self.page.update()
    def show_module_name_autocomplete_option        (self, e: ft.ControlEvent):
        del self.right_side_column.controls[1]
        self.right_side_column.controls.insert(1, self.module_name_autocomplete_option)
        self.page.update()



    def show_related_subject_textfield_option       (self, e: ft.ControlEvent):
        del self.left_side_column.controls[3]
        self.left_side_column.controls.insert(3, self.related_subjects_textfield_option)
        self.page.update()
    def show_related_subject_autocomplete_option    (self,e: ft.ControlEvent):
        del self.left_side_column.controls[3]
        self.left_side_column.controls.insert(3, self.related_subjects_autocomplete_option)
        self.page.update()
    def add_to_related_subjects                     (self,e: ft.ControlEvent, subject_inputted):
        current_subject_list = [i for i in self.related_subjects_display.value.split("\n")]
        # Avoid duplication
        if subject_inputted not in current_subject_list:
            if self.related_subjects_display.value == None or self.related_subjects_display.value == "":
                self.related_subjects_display.value += f"{subject_inputted}"
            else:
                self.related_subjects_display.value += f"\n{subject_inputted}"
        self.update_related_subject([i for i in self.related_subjects_display.value.split("\n")])
        self.page.update()
    def clear_related_subjects_field                (self,e: ft.ControlEvent):
        self.related_subjects_display.value=""
        self.update_related_subject(None)
        self.page.update()



    def show_related_concepts_textfield_option      (self,e: ft.ControlEvent):
        del self.right_side_column.controls[3]
        self.right_side_column.controls.insert(3, self.related_concepts_textfield_option)
        self.page.update()

    def show_related_concepts_autocomplete_option   (self,e: ft.ControlEvent):
        del self.right_side_column.controls[3]
        self.right_side_column.controls.insert(3, self.related_concepts_autocomplete_option)
        self.page.update()

    def add_to_related_concepts                     (self,e: ft.ControlEvent, concept_inputted):
        current_concept_list = [i for i in self.related_concepts.value.split("\n")]
        # Avoid duplication
        if concept_inputted not in current_concept_list:
            if self.related_concepts.value == None or self.related_concepts.value == "":
                self.related_concepts.value += f"{concept_inputted}"
            else:
                self.related_concepts.value += f"\n{concept_inputted}"
        self.update_related_concepts([i for i in self.related_concepts.value.split("\n")])
        self.page.update()
    def clear_related_concepts_field                (self, e: ft.ControlEvent):
        self.related_concepts.value=""
        self.update_related_concepts(None)
        self.page.update()

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
                self.question_image.icon_color = ft.colors.GREEN
            elif media_type == "audio":
                # Audio not currently supported
                pass #FIXME
                # question_audio.data = file_path
                # question_preview_audio.src = file_path
                # question_preview_audio.autoplay=True
                # question_preview_audio.volume = 1
                # question_audio.icon_color = ft.colors.GREEN
            elif media_type == "video":
                # Video not currently supported
                pass #FIXME
                # question_video.data = file_path
                # question_video.icon_color = ft.colors.GREEN
        elif self.q_or_a =="answer_media":
            print("Answer being uploaded")
            if media_type == "image":
                self.update_answer_image(self.file_picker.result.files[0].name)
                self.answer_preview_image.src = file_path
                self.answer_preview_image.height = 100
                self.answer_image.icon_color = ft.colors.GREEN
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
# Update internal form value functions
#   These functions update the hidden variable inside the page, which are accessed when the submit button is pressed
    def update_primary_subject(self, new_data):
        self.primary_subject_submission = new_data
        print("New Primary subject value:",self.primary_subject_submission)

    def update_module_name(self, new_data):
        self.module_name_submission = new_data
        print(f"New Module Name value: {self.module_name_submission}")

    def update_related_subject(self, new_data):
        self.related_subjects_submission = new_data
        print(f"New related_subjects field value: {self.related_subjects_submission}")

    def update_related_concepts(self, new_data):
        self.related_concepts_submission = new_data
        print(f"New related concepts value: {self.related_concepts_submission}")

    def update_question_text(self, new_data):
        self.question_text_submission = new_data
        print(f"New Question Text Value: {self.question_text_submission}")

    def update_question_image(self, new_data):
        self.question_image_submission = new_data
        print(f"New Question Image Value: {self.question_image_submission}")

    def update_question_audio(self, new_data):
        self.question_audio_submission = new_data
        print(f"New Question Audio Value: {self.question_audio_submission}")

    def update_question_video(self, new_data):
        self.question_video_submission = new_data
        print(f"New Question Video Value: {self.question_video_submission}")

    def update_answer_text(self, new_data):
        self.answer_text_submission = new_data
        print(f"New Answer Text Value: {self.answer_text_submission}")

    def update_answer_image(self, new_data):
        self.answer_image_submission = new_data
        print(f"New Answer Image Value: {self.answer_image_submission}")

    def update_answer_audio(self, new_data):
        self.answer_audio_submission = new_data
        print(f"New Answer Audio Value: {self.answer_audio_submission}")

    def update_answer_video(self, new_data):
        self.answer_video_submission = new_data
        print(f"New Answer Video Value: {self.answer_video_submission}")

################
# Submission Button functions
    def clear_form_fields(self, e = None):
        # Leave the page, then reload the same page
        self.go_to_home_screen()
        self.go_to_add_question_page()

    def submit_question(self, e):
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
                self.module_name_text.color = ft.colors.RED
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
                os.remove(f"uploads/{filename}")

        

        self.clear_form_fields()