import flet as ft
import public_functions
import system_data
from lib import helper

class module_card(ft.Row):
    '''
    For use in the display modules page
    Displays the name of a module and provides options to either edit the questions within it 
    or
    Deactivate and Activate the module
    '''
    def __init__(self, name_of_module, user_profile_data, all_module_data, question_object_data):
        super().__init__()
        self.name                   = name_of_module[:] # Ensure we create a copy of the string so we don't mutate it elsewhere
        self.all_module_data        = all_module_data
        self.user_profile_data      = user_profile_data
        self.question_object_data   = question_object_data
        self.expand = True
        try:
            self.is_activated       = user_profile_data["settings"]["module_settings"]["module_status"][name_of_module]
            self.module_in_profile  = True
        except KeyError as e:
            self.is_activated       = False
            self.module_in_profile  = False
        self.alignment = ft.MainAxisAlignment.START
        # Module metadata
        # the name of the module displays first

        self.name_bar = ft.Text(value=self.name.title())
        # The primary subject gets displayed
        self.primary_subject = ft.Text(value=f"Primary Subject: {all_module_data[name_of_module]['primary_subject']}")
        self.add_module_to_user_profile_button = ft.IconButton(
            icon=ft.Icons.SAVE,
            icon_color=ft.Colors.BLACK,
            bgcolor=ft.Colors.WHITE,
            on_click=lambda e: self.add_question()
        )

        # Buttons for the control row
        self.edit_module_button     = ft.IconButton(
            icon=ft.Icons.EDIT,
            icon_color=ft.Colors.BLACK,
            bgcolor=ft.Colors.WHITE,
            on_click= lambda e: print("Route to edit_module_page")
        )
        
        self.checkbox_button        = ft.Checkbox(
            label="Is Activated",
            value = self.is_activated,
            on_change = lambda e: self.update_module(e)
        )

        self.controls_row           = ft.Row(
            controls=[
                self.edit_module_button,
                self.checkbox_button
            ],
            alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
            expand=True
        )
        # Conditionally add in a button to add a module to a user's profile
        # Further, on program initialization we need to do a check to see if any module questions exist that aren't in the user's profile
        if self.module_in_profile == False:
            self.checkbox_button.disabled=True
            self.checkbox_button.label="You don't own this module yet"
            self.controls_row.controls.append(self.add_module_to_user_profile_button)
        
        self.column_element         = ft.Column(
            controls=[
                self.name_bar,
                self.primary_subject,
                self.controls_row
            ]
        )

        self.controls               = [
            self.column_element
        ]

    def add_question(self, e = None):
        # add the module to the module_status
        self.user_profile_data = system_data.activate_module_in_user_profile(
                self.name,
                self.user_profile_data,
                self.all_module_data,
                self.question_object_data)
        self.checkbox_button.value      = True
        self.checkbox_button.label      = "Is Activated"
        self.checkbox_button.disabled   = False
        self.controls_row.controls      = [
            self.edit_module_button,
            self.checkbox_button
            ]
        # Ensure we actually add those questions into the user module
        # Then sort them into the reserve bank or deactivated bank by default
        self.user_profile_data["questions"] = system_data.sort_questions(self.user_profile_data, self.question_object_data)
        self.page.update()

    def update_module(self, e = None):
        value   = e.data
        if value == "true":
            self.user_profile_data = system_data.activate_module_in_user_profile(
                self.name,
                self.user_profile_data,
                self.all_module_data,
                self.question_object_data)
        elif value == "false":
            self.user_profile_data = system_data.deactivate_module_in_user_profile(
                self.name,
                self.user_profile_data,
                self.all_module_data,
                self.question_object_data
            )

class PrimarySubjectField(ft.Container):
    def __init__(self, question_object_data, form_fields_width, current_question_id = None):
        super().__init__()
        # Defines
        self.current_question_id            = current_question_id
        self.question_object_data           = question_object_data
        self.form_fields_width              = form_fields_width
        if current_question_id != None:
            self.question_object            = question_object_data[current_question_id]
        else:
            self.question_object            = {}
        try:
            self.submission                 = self.question_object["primary_subject"]
        except KeyError:
            try:
                self.submission             = self.question_object["subject"][0]
            except KeyError:
                self.submission             = ""
        self.subject_data                   = system_data.get_subject_data()
            # Access this in the main page to get the value of what's in the box

        self.primary_subject_text                   = ft.Text(
            value   = "Primary Subject", 
            size    = 24,
            tooltip = "What is the Primary Subject, or Field of Study, of this question?\n For example is this a biology question, anatomy, mathematics, calculus, history, etc.")
        
        self.primary_subject_textfield              = ft.TextField(
            value=self.submission,
            width=self.form_fields_width,
            on_change=lambda e: self.update_primary_subject(e.data)
            )
        
        self.primary_subject_back_button            = ft.IconButton(
            icon=ft.Icons.ARROW_BACK, 
            icon_color=ft.Colors.BLACK, 
            tooltip="Select from from list", 
            bgcolor=ft.Colors.WHITE, 
            on_click=self.show_primary_subject_autocomplete_option)
        
        self.add_new_primary_subject_button         = ft.IconButton(
            icon=ft.Icons.ADD, 
            icon_color=ft.Colors.BLACK, 
            tooltip="Add a subject that isn't in the list", 
            bgcolor=ft.Colors.WHITE, 
            on_click=self.show_primary_subject_textfield_option)
        
        self.primary_subject_input                  = ft.AutoComplete(
            suggestions=[ft.AutoCompleteSuggestion(key=i, value=i) for i in self.subject_data.keys()],
            on_select=lambda e: self.update_primary_subject(e.selection.value))

        self.primary_subject_textfield_option       = ft.Row(
            controls=[
                self.primary_subject_textfield, 
                self.primary_subject_back_button],
            alignment=ft.MainAxisAlignment.CENTER    
            )
        
        self.primary_subject_autocomplete_option    = ft.Row(
            controls=[ft.Column(
                controls=[
                    ft.Stack(
                        controls=[self.primary_subject_input],
                        width=self.form_fields_width), 
                    self.add_new_primary_subject_button], 
                height=75, 
                wrap=True)],
            alignment=ft.MainAxisAlignment.CENTER
            )
        
        self.display_field                          = ft.TextField(
            disabled    = True,
            value       = str(self.submission),
            width       = self.form_fields_width
        )
        self.content_box_autocomplete               = ft.Column(
            controls=[
                self.primary_subject_text,
                self.display_field,
                self.primary_subject_autocomplete_option
            ],
            horizontal_alignment= ft.CrossAxisAlignment.CENTER
        )
        self.content_box_textfield                  = ft.Column(
            controls=[
                self.primary_subject_text,
                self.display_field,
                self.primary_subject_textfield_option
            ],
            horizontal_alignment= ft.CrossAxisAlignment.CENTER
        )
        self.content                                = self.content_box_autocomplete

        
    def show_primary_subject_textfield_option       (self, e: ft.ControlEvent):
        self.content = self.content_box_textfield
        self.page.update()
    def show_primary_subject_autocomplete_option    (self, e:ft.ControlEvent):
        self.content = self.content_box_autocomplete
        self.page.update()
    def update_primary_subject(self, new_data):
        self.submission             = new_data
        self.display_field.value    = str(self.submission).lower()
        self.submission             = self.display_field.value
        # print("New Primary subject value:", self.submission)
        self.page.update()

class ModuleNameField(ft.Container):
    def __init__(self, question_object_data, form_fields_width, all_module_data, current_question_id = None):
        super().__init__()
        # Defines
        self.current_question_id            = current_question_id
        self.question_object_data           = question_object_data
        self.all_module_data                = all_module_data
        self.form_fields_width              = form_fields_width

        if current_question_id != None:
            self.question_object            = question_object_data[current_question_id]
            self.submission                 = self.question_object["module_name"]
        else:
            self.submission                 = ""
        self.module_name_text               = ft.Text(
            value       = "Define the Module:",
            size        = 24,
            tooltip     = "What module does the question belong to?\n Begin by typing the name of the module, you'll be given a list of suggestions based on what modules already exist by that name\n You can contribute to any module \n BE AWARE: adding a question to a pre-existing module, will import that module into your profile\n Please Avoid adding duplicate questions to a module"
        )

        self.module_name_textfield          = ft.TextField(
            value       = self.submission,
            width       = self.form_fields_width,
            on_change   = lambda e: self.update_module_name(e.data)
        )

        self.module_name_back_button                = ft.IconButton(
            icon=ft.Icons.ARROW_BACK, 
            icon_color=ft.Colors.BLACK, 
            tooltip="Add a subject that isn't in the list", 
            bgcolor=ft.Colors.WHITE, 
            on_click=self.show_module_name_autocomplete_option)
        
        self.add_new_module_button                  = ft.IconButton(
            icon=ft.Icons.ADD, 
            icon_color=ft.Colors.BLACK, 
            tooltip="Add a subject that isn't in the list", 
            bgcolor=ft.Colors.WHITE, 
            on_click=self.show_module_name_textfield_option)

        self.module_name_input                      = ft.AutoComplete(
            suggestions=[ft.AutoCompleteSuggestion(key=i, value=i) for i in self.all_module_data.keys()],
            on_select=lambda e: self.update_module_name(e.selection.value))

        self.module_name_textfield_option           = ft.Row(
            controls=[
                self.module_name_textfield, 
                self.module_name_back_button],
            alignment=ft.MainAxisAlignment.CENTER
            )
        
        self.module_name_autocomplete_option        = ft.Row(
            controls=[ft.Column(
                controls=[
                    ft.Stack(
                        controls=[self.module_name_input],
                        width=self.form_fields_width), 
                    self.add_new_module_button], 
                height=75, 
                wrap=True)],
            alignment=ft.MainAxisAlignment.CENTER
            ) 
        self.display_field                          = ft.TextField(
            disabled    = True,
            value       = str(self.submission),
            width       = self.form_fields_width
        )
        self.content_box_textfield = ft.Column(
            controls=[
                self.module_name_text,
                self.display_field,
                self.module_name_textfield_option
            ],
            horizontal_alignment= ft.CrossAxisAlignment.CENTER
        )
        self.content_box_autocomplete = ft.Column(
            controls=[
                self.module_name_text,
                self.display_field,
                self.module_name_autocomplete_option
            ],
            horizontal_alignment= ft.CrossAxisAlignment.CENTER
        )

        self.content                                = self.content_box_autocomplete
    def update_module_name(self, new_data):
        self.submission = new_data
        self.display_field.value = str(self.submission).lower()
        # print(f"New Module Name value: {self.submission}")
        self.page.update()
    def show_module_name_textfield_option           (self, e: ft.ControlEvent):
        self.content = self.content_box_textfield
        self.page.update()
    def show_module_name_autocomplete_option        (self, e: ft.ControlEvent):
        self.content = self.content_box_autocomplete
        self.page.update()
    
        
class RelatedSubjectsField(ft.Container):
    def __init__(self, question_object_data, form_fields_width, current_question_id = None):
        super().__init__()
        # Defines
        self.current_question_id            = current_question_id
        self.question_object_data           = question_object_data
        
        self.form_fields_width              = form_fields_width
        self.subject_data                   = system_data.get_subject_data()
        
        if current_question_id != None:
            self.question_object                = question_object_data[current_question_id]
            self.submission                     = self.question_object["subject"]
        else:
            self.submission                     = ["miscellaneous"]
        self.related_subjects_textfield             = ft.TextField(
            width=self.form_fields_width, 
            on_submit=lambda e: self.add_to_related_subjects(e, self.related_subjects_textfield.value))
        
        self.related_subjects_display               = ft.TextField(
            label="Related Subjects",
            tooltip="What other subjects relate to this question?\n For example it might be a calculus question, but calculus also falls under mathematics, \nThe question may also be referrencing a historical event, thus related to history as well",
            multiline=True, 
            disabled=True, 
            width=self.form_fields_width)
        try:
            self.related_subjects_display.value ="\n".join(self.submission)
        except TypeError: # If the value for submission is none, the above causes a type error since you join a None Type object
            # Set display to None if no question is fed in
            self.related_subjects_display.value = None

        self.clear_related_subject_display_button           = ft.IconButton(
            icon=ft.Icons.CLEAR, 
            icon_color=ft.Colors.BLACK, 
            tooltip="Clear The Related Subjects Input Field", 
            bgcolor=ft.Colors.WHITE, 
            on_click=self.clear_related_subjects_field)
        
        self.related_subjects_back_button                   = ft.IconButton(
            icon=ft.Icons.ARROW_BACK, 
            icon_color=ft.Colors.BLACK, 
            tooltip="Clear The Related Subjects Input Field", 
            bgcolor=ft.Colors.WHITE, 
            on_click=self.show_related_subject_autocomplete_option)
        
        self.add_new_related_subject_button                 = ft.IconButton(
            icon=ft.Icons.ADD, 
            icon_color=ft.Colors.BLACK, 
            tooltip="Add a subject that isn't in the list", 
            bgcolor=ft.Colors.WHITE, 
            on_click=self.show_related_subject_textfield_option)
        
        self.related_subjects_autocomplete_input    = ft.AutoComplete(
            suggestions=[ft.AutoCompleteSuggestion(key=i, value=i) for i in self.subject_data.keys()],
            on_select=lambda e: self.add_to_related_subjects(e, e.selection.value))
        
        self.related_subjects_display_row = ft.Row(
            controls=[
                self.related_subjects_display, 
                self.clear_related_subject_display_button],
            alignment=ft.MainAxisAlignment.CENTER    
            )
        
        self.related_subjects_autocomplete_option   = ft.Row(
            controls=[
                ft.Column(
                    controls=[
                        ft.Stack(
                            controls=[self.related_subjects_autocomplete_input],
                            width=self.form_fields_width), 
                        self.add_new_related_subject_button], 
                    height=75, 
                    wrap=True)],
            alignment=ft.MainAxisAlignment.CENTER        
            )
        
        self.related_subjects_textfield_option      = ft.Row(
            controls=[
                self.related_subjects_textfield, 
                self.related_subjects_back_button],
            alignment=ft.MainAxisAlignment.CENTER
            )
        self.content_box_textfield                  = ft.Column(
            controls=[
                ft.Text(value="All Related Subjects", size=24),
                self.related_subjects_display_row,
                self.related_subjects_textfield_option
            ],
            horizontal_alignment= ft.CrossAxisAlignment.CENTER
        )
        self.content_box_autocomplete               = ft.Column(
            controls=[
                ft.Text(value="All Related Subjects", size=24),
                self.related_subjects_display_row,
                self.related_subjects_autocomplete_option
            ],
            horizontal_alignment= ft.CrossAxisAlignment.CENTER

        )
        self.content = self.content_box_autocomplete

    def show_related_subject_textfield_option       (self, e: ft.ControlEvent):
        self.content = self.content_box_textfield
        self.page.update()
    def show_related_subject_autocomplete_option    (self,e: ft.ControlEvent):
        self.content = self.content_box_autocomplete
        self.page.update()
    def add_to_related_subjects                     (self,e: ft.ControlEvent = None, subject_inputted = ""):
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
    def update_related_subject(self, new_data):
        self.submission = new_data
        # print(f"New related_subjects field value: {self.submission}")

        
class RelatedConceptsField(ft.Container):
    def __init__(self, question_object_data, form_fields_width, current_question_id = None):
        super().__init__()
        # Defines
        self.current_question_id            = current_question_id
        self.question_object_data           = question_object_data
        
        self.form_fields_width              = form_fields_width
        
        self.concept_data                   = system_data.get_concept_data()
        if current_question_id != None:
            self.question_object            = question_object_data[current_question_id]
            self.submission                 = self.question_object["related"]
        else:
            self.submission                 = None

        self.related_concepts_textfield             = ft.TextField(
            width=self.form_fields_width, 
            on_submit=lambda e: self.add_to_related_concepts(e, self.related_concepts_textfield.value))
        
        self.related_concepts = ft.TextField(
            label="Related Concepts and Terms",           
            tooltip="What concepts and terms are related to this question?\nFor example the question What year was xyz invented and who invented it? points to the term xyz, to the historical period, and to the individual\n",
            multiline=True, 
            disabled=True, 
            width=self.form_fields_width)
        try:
            self.related_concepts.value = "\n".join(self.submission)
        except TypeError:
            self.related_concepts.value = None
        
        self.related_concepts_back_button                   = ft.IconButton(
            icon=ft.Icons.ARROW_BACK, 
            icon_color=ft.Colors.BLACK, 
            tooltip="Clear the Related Concepts Input Field", 
            bgcolor=ft.Colors.WHITE, 
            on_click=self.show_related_concepts_autocomplete_option)
        
        self.clear_related_button                           = ft.IconButton(
            icon=ft.Icons.CLEAR, 
            icon_color=ft.Colors.BLACK, 
            tooltip="Clear the Related Concepts Input Field", 
            bgcolor=ft.Colors.WHITE, 
            on_click=self.clear_related_concepts_field)
        
        self.add_new_concept_button                         = ft.IconButton(
            icon=ft.Icons.ADD, 
            icon_color=ft.Colors.BLACK, 
            tooltip="Add a concept that isn't in the list", 
            bgcolor=ft.Colors.WHITE, 
            on_click=self.show_related_concepts_textfield_option)
        
        self.concept_auto_complete                       = ft.AutoComplete(
            suggestions=[ft.AutoCompleteSuggestion(key=i, value=i) for i in self.concept_data.keys()],
            on_select=lambda e: self.add_to_related_concepts(e, e.selection.value))
        
        self.related_concepts_display_row           = ft.Row(
            controls=[
                self.related_concepts, 
                self.clear_related_button],
            alignment=ft.MainAxisAlignment.CENTER
            )
        
        self.related_concepts_autocomplete_option   = ft.Row(
            controls=[
                ft.Column(
                    controls=[
                        ft.Stack(
                            controls=[self.concept_auto_complete],
                            width=self.form_fields_width), 
                        self.add_new_concept_button], 
                    height=75, 
                    wrap=True)],
            alignment=ft.MainAxisAlignment.CENTER
            )
        self.related_concepts_textfield_option      = ft.Row(
            controls=[
                self.related_concepts_textfield, 
                self.related_concepts_back_button],
            alignment=ft.MainAxisAlignment.CENTER
            )
        
        self.content_box_textfield                  = ft.Column(
            controls = [
                ft.Text(value="All Related Concepts", size = 24),
                self.related_concepts_display_row,
                self.related_concepts_textfield_option
            ],
            horizontal_alignment= ft.CrossAxisAlignment.CENTER
        )

        self.content_box_autocomplete               = ft.Column(
            controls = [
                ft.Text(value="All Related Concepts", size = 24),
                self.related_concepts_display_row,
                self.related_concepts_autocomplete_option
            ],
            horizontal_alignment= ft.CrossAxisAlignment.CENTER
        )

        self.content = self.content_box_autocomplete

    def show_related_concepts_textfield_option      (self,e: ft.ControlEvent):
        self.content = self.content_box_textfield
        self.page.update()

    def show_related_concepts_autocomplete_option   (self,e: ft.ControlEvent):
        self.content = self.content_box_autocomplete
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

    def update_related_concepts(self, new_data):
        self.submission = new_data
        # print(f"New related concepts value: {self.submission}")

class QuestionEntryField(ft.Container):
    def __init__(self, page, question_object_data, form_fields_width, current_question_id = None):
        super().__init__()
        # Defines
        self.page                           = page
        self.current_question_id            = current_question_id
        self.question_object_data           = question_object_data
        
        self.form_fields_width              = form_fields_width
        if current_question_id != None:
            self.question_object                = question_object_data[current_question_id]
            self.text_submission                = self.question_object["question_text"]
            self.image_submission               = self.question_object["question_image"]
            self.audio_submission               = self.question_object["question_audio"]
            self.video_submission               = self.question_object["question_video"]
        else:
            self.text_submission                = None
            self.image_submission               = None
            self.audio_submission               = None
            self.video_submission               = None
        self.file_picker = ft.FilePicker(
            on_result=self.dialog_result,
            on_upload=self.upload_file)
        self.page.overlay.append(self.file_picker)
        self.page.update()      
        self.text_field                                 = ft.TextField(
            label       = "Question Text",
            width       = self.form_fields_width,
            multiline   = True,
            tooltip     = "What's the Question?",
            expand      = True,
            on_change   = lambda e: self.update_text_field(e.data)
        )
        self.text_field.value = self.text_submission

        self.preview_image                              = ft.Image(
            src=f"system_data/media_files/{self.image_submission}"
        )

        if self.image_submission != None:
            self.preview_image.src = self.image_submission

        self.preview_audio                              = ft.Text(
            value="Audio Not Currently Supported"
        )

        self.preview_video                              = ft.Text(
            value   = "Video Not Currently Supported"
        )
        self.image_status                               = ft.IconButton(
            icon=ft.Icons.IMAGE, 
            icon_color=ft.Colors.RED, 
            data="")
        
        self.audio_status                               = ft.IconButton(
            icon=ft.Icons.AUDIO_FILE, 
            icon_color=ft.Colors.RED, 
            data="")
        
        self.video_status                               = ft.IconButton(
            icon=ft.Icons.VIDEO_FILE, 
            icon_color=ft.Colors.RED, 
            data="")
        
        self.media_upload_button               = ft.ElevatedButton(
            text="Upload Question Media", 
            tooltip="Quizzer will automatically detect whether the media you upload is an image, audio, or video file,\n Alternatively you can drag and drop the media into the interface\nRED indicates no media for that type (image, audio, video)\n GREEN indicates you've added that type of media to the question",
            data="question_media", 
            on_click=lambda _: self.upload_media(self.media_upload_button.data))                     

        self.media_status      = ft.Row(
            alignment=ft.MainAxisAlignment.SPACE_AROUND,
            controls    =[
                self.image_status,
                self.audio_status,
                self.video_status
            ],
            width       = self.form_fields_width
        )
        
        self.content_box                                = ft.Column(
            controls=[
                self.text_field,
                self.preview_image,
                self.preview_audio,
                self.preview_video,
                self.media_status,
                self.media_upload_button
            ],
            horizontal_alignment= ft.CrossAxisAlignment.CENTER
        )

        self.content = self.content_box
    def update_text_field(self, new_data):
        self.text_submission    = new_data
        self.text_field.value   = self.text_submission
        # print(f"New Question Text Value: {self.text_submission}")
        self.page.update()

    def update_question_image(self, new_data):
        self.image_submission   = new_data
        self.preview_image.src  = self.image_submission
        # print(f"New Question Image Value: {self.image_submission}")

    def update_question_audio(self, new_data):
        self.audio_submission   = new_data
        # print(f"New Question Audio Value: {self.audio_submission}")

    def update_question_video(self, new_data):
        self.video_submission = new_data
        # print(f"New Question Video Value: {self.video_submission}")

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
        # print(self.file_picker.result.files[0].path)
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
                self.preview_image.src = file_path
                self.preview_image.height = 100
                self.image_status.icon_color = ft.Colors.GREEN
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
                # question_video.icon_color = ft.colors.GREEN
        self.page.update()

    def upload_media(self,status):
        self.file_picker.pick_files()
        self.page.update()
        self.q_or_a = status

class AnswerEntryField(ft.Container):
    def __init__(self, page, question_object_data, form_fields_width, current_question_id = None):
        super().__init__()
        # Defines
        self.page                           = page
        self.current_question_id            = current_question_id
        self.question_object_data           = question_object_data
        self.form_fields_width              = form_fields_width
        if current_question_id != None:
            self.question_object                = question_object_data[current_question_id]
            self.text_submission                = self.question_object["answer_text"]
            self.image_submission               = self.question_object["answer_image"]
            self.audio_submission               = self.question_object["answer_audio"]
            self.video_submission               = self.question_object["answer_video"]
        else:
            self.text_submission                = None
            self.image_submission               = None
            self.audio_submission               = None
            self.video_submission               = None

        self.file_picker = ft.FilePicker(
            on_result=self.dialog_result,
            on_upload=self.upload_file)
        self.page.overlay.append(self.file_picker)
        self.page.update()      
        self.text_field                                 = ft.TextField(
            label       = "Answer Text",
            width       = self.form_fields_width,
            multiline   = True,
            tooltip     = "What's the Question?",
            expand      = True,
            on_change   = lambda e: self.update_text_field(e.data)
        )
        self.text_field.value = self.text_submission

        self.preview_image                              = ft.Image(
            src=f"system_data/media_files/{self.image_submission}"
        )

        self.preview_audio                              = ft.Text(
            value="Audio Not Currently Supported"
        )

        self.preview_video                              = ft.Text(
            value   = "Video Not Currently Supported"
        )
        self.image_status                               = ft.IconButton(
            icon=ft.Icons.IMAGE, 
            icon_color=ft.Colors.RED, 
            data="")
        
        self.audio_status                               = ft.IconButton(
            icon=ft.Icons.AUDIO_FILE, 
            icon_color=ft.Colors.RED, 
            data="")
        
        self.video_status                               = ft.IconButton(
            icon=ft.Icons.VIDEO_FILE, 
            icon_color=ft.Colors.RED, 
            data="")
        
        self.media_upload_button               = ft.ElevatedButton(
            text="Upload Answer Media", 
            tooltip="Quizzer will automatically detect whether the media you upload is an image, audio, or video file,\n Alternatively you can drag and drop the media into the interface\nRED indicates no media for that type (image, audio, video)\n GREEN indicates you've added that type of media to the question",
            data="answer_media", 
            on_click=lambda _: self.upload_media(self.media_upload_button.data))                     

        self.media_status      = ft.Row(
            alignment=ft.MainAxisAlignment.SPACE_AROUND,
            controls    =[
                self.image_status,
                self.audio_status,
                self.video_status
            ],
            width       = self.form_fields_width
        )
        
        self.content_box                                = ft.Column(
            controls=[
                self.text_field,
                self.preview_image,
                self.preview_audio,
                self.preview_video,
                self.media_status,
                self.media_upload_button
            ],
            horizontal_alignment= ft.CrossAxisAlignment.CENTER
        )

        self.content = self.content_box
    def update_text_field(self, new_data):
        self.text_submission    = new_data
        self.text_field.value   = self.text_submission
        # print(f"New Answer Text Value: {self.text_submission}")
        self.page.update()

    def update_image_field(self, new_data):
        self.image_submission   = new_data
        self.preview_image.src  = self.image_submission
        # print(f"New Answer Image Value: {self.image_submission}")

    def update_audio_field(self, new_data):
        self.audio_submission   = new_data
        # print(f"New Answer Audio Value: {self.audio_submission}")

    def update_video_field(self, new_data):
        self.video_submission = new_data
        # print(f"New Answer Video Value: {self.video_submission}")

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
        if self.q_or_a == "answer_media":
            # print("Answer being uploaded")
            if media_type == "image":
                self.update_image_field(self.file_picker.result.files[0].name)
                self.preview_image.src= f"uploads/{self.image_submission}"
                self.preview_image.height = 100
                self.image_status.icon_color = ft.Colors.GREEN
                self.page.update()
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

    def upload_media(self,status):
        self.file_picker.pick_files()
        self.page.update()
        self.q_or_a = status