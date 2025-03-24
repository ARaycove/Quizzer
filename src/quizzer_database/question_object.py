from datetime   import datetime, timedelta, date
from lib        import quizzer_logger as ql
# Constructor fails if all question fields are None or all answer fields are None
class QuestionObject():
    '''
    Core class for Quizzer, this object holds a question and answer pair along with data that describes how it relates to core concepts and subject matters.

    - media related fields should be file paths to the associated media file, not a blob file itself. Future iterations will experiment with embedding media directly into the object for easier storage.
    '''
    ###############################################################################
    # Dan da Dan
    ###############################################################################
    @ql.log_function()
    def __init__(self,
                 author:            str,
                 id:                str     = None,
                 module_name:       str     = None,
                 primary_subject:   str     = None,
                 subjects:          list    = None,
                 related_concepts:  list    = None,
                 question_text:     str     = None,
                 question_audio:    str     = None,
                 question_image:    str     = None,
                 question_video:    str     = None,
                 answer_text:       str     = None,
                 answer_audio:      str     = None,
                 answer_image:      str     = None,   
                 answer_video:      str     = None,
                 ):
        # Some items much be lowercased
        self.__id                 = id                
        self.__primary_subject    = primary_subject
        self.__subjects           = subjects,             # None handled in build function
        self.__related_concepts   = related_concepts      # None handled in build function
        self.__question_text      = question_text
        self.__question_audio     = question_audio
        self.__question_image     = question_image
        self.__question_video     = question_video
        self.__answer_text        = answer_text
        self.__answer_audio       = answer_audio
        self.__answer_image       = answer_image
        self.__answer_video       = answer_video
        self.__module_name        = module_name  # None handled in build function
        self.__author           = author
        self._build_question_object()

    def __str__(self):
        result = f"QuestionObject @ Memory:{id(self)}\n"
        for key, value in self.__dict__.items():
           result += f"{key:25}|{value}\n"
        return result

    def __eq__(self, other):
        if not isinstance(other, QuestionObject):
            return False
        return self.__dict__ == other.__dict__
    ###############################################################################
    # Initial Build and Verification of Fields
    ###############################################################################
    
    @ql.log_function()
    def _calculate_question_id(self) -> dict:
        '''
        Generates the id for the inputted question object, only run if the QuestionObject does not already have an id.

        Unique id is determined by the current time and the author concatenated
        '''
        current_time = str(datetime.now())
        return current_time + "_" + self.author

    @ql.log_function()
    def _verify_question_answer_fields(self):
        @ql.log_function()
        def _verify_question_field_present(self: QuestionObject):
            total_question_fields = 0
            if self.__question_text != None:
                total_question_fields += 1
            elif self.__question_audio != None:
                total_question_fields += 1
            elif self.__question_image != None:
                total_question_fields += 1
            elif self.__question_video != None:
                total_question_fields += 1
            return total_question_fields
        @ql.log_function()
        def _verify_answer_field_present(self: QuestionObject):
            total_answer_fields = 0
            if self.__answer_text != None:
                total_answer_fields += 1
            elif self.__answer_audio != None:
                total_answer_fields += 1
            elif self.__answer_image != None:
                total_answer_fields += 1
            elif self.__answer_video != None:
                total_answer_fields += 1
            return total_answer_fields
        answer_field_present    = _verify_answer_field_present(self)
        question_field_present  = _verify_question_field_present(self)
        if answer_field_present == 1 and question_field_present == 1:
            # print("QuestionObject Valid")
            pass
        else:
            raise Exception("QuestionObject must have at least 1 answer field and 1 question field to be valid")

    @ql.log_function()
    def _build_question_object(self):
        self._verify_question_answer_fields()
        
        # All question objects must have at least one subject matter to which it relates, if none is passed, default to miscellaneous
        ql.log_general_message("Traceback says self.subjects is Nonetype none iterable")
        ql.log_value("self.subjects", self.__subjects)
        if self.__subjects == None or self.__subjects == (None,):
            self.__subjects = list(["miscellaneous"])
            ql.log_general_message("strange, let's confirm it's now appropriately types")
            ql.log_value("self.subjects", self.__subjects)

        elif isinstance(self.__subjects, tuple):
            self.__subjects = self.__subjects[0]
        if self.__primary_subject == None:
            self.__primary_subject = self.__subjects[0]

        for subject in self.__subjects:
            subject = str(subject).lower()
        # All question objects has concepts and terms to which it relates, stored in an array, if nothing specified, then initialize to an empty array
        if self.__related_concepts == None or self.__related_concepts == (None,):
            self.__related_concepts = []
        for concept in self.__related_concepts:
            concept: str = concept.lower()
        # Modules are there to share batches of questions, and to quickly tell Quizzer what to include as eligible, overriding core functionality if desired.
        if self.__module_name == None:
            self.__module_name = "default_module" 
        else:
            self.__module_name = self.__module_name.lower()
        # id is dependent on author:
        if self.__id == None:
            self.__id = self._calculate_question_id()
    ###############################################################################
    # Initial Build and Verification of Fields
    ###############################################################################
    # Prevent author from being changed
    #---------------
    @property
    def id(self):
        try:
            return self.__id
        except AttributeError:
            if 'id' in self.__dict__:
                self.__id = self.__dict__['id']
                del self.__dict__['id']
            return self.__id
    
    @ql.log_function()
    def set_id_value(self, value):
        ql.log_warning("Initial question_id is not to be changed, aborting action")

    #---------------    
    @property
    def primary_subject(self):
        try:
            return self.__primary_subject
        except AttributeError:
            if 'primary_subject' in self.__dict__:
                self.__primary_subject = self.__dict__['primary_subject']
                del self.__dict__['primary_subject']
            return self.__primary_subject
    
    @ql.log_function()
    def set_primary_subject_value(self, value):
        if not isinstance(value, str):
            ql.log_warning("Can't update primary subject with non-str obj")
            ql.log_value("value", value)
            return None
        else:
            self.__primary_subject = value
    #---------------    
    @property
    def subjects(self):
        try:
            return self.__subjects
        except AttributeError:
            if 'subjects' in self.__dict__:
                self.__subjects = self.__dict__['subjects']
                del self.__dict__['subjects']
            return self.__subjects
    
    @ql.log_function()
    def set_subjects_value(self, value):
        if not isinstance(value, list):
            ql.log_warning("updated subjects should be a list of subject strings")
            return None
        else:
            self.__subjects = [str(subject).lower() for subject in value]
    #---------------    
    @property
    def related_concepts(self):
        try:
            return self.__related_concepts
        except AttributeError:
            if 'related_concepts' in self.__dict__:
                self.__related_concepts = self.__dict__['related_concepts']
                del self.__dict__['related_concepts']
            return self.__related_concepts
    
    @ql.log_function()
    def set_related_concepts_value(self, value):
        if not isinstance(value, list):
            ql.log_warning("updated subjects should be a list of subject strings")
            return None
        else:
            self.__related_concepts = [str(concept).lower() for concept in value]

    #---------------    
    @property
    def question_text(self):
        try:
            return self.__question_text
        except AttributeError:
            if 'question_text' in self.__dict__:
                self.__question_text = self.__dict__['question_text']
                del self.__dict__['question_text']
            return self.__question_text
    
    @ql.log_function()
    def set_question_text_value(self, value):
        if not isinstance(value, str):
            ql.log_warning("Can't update question_text with non-str obj")
            ql.log_value("value", value)
            return None
        else:
            self.__question_text = value
    #---------------    
    @property
    def question_audio(self):
        try:
            return self.__question_audio
        except AttributeError:
            if 'question_audio' in self.__dict__:
                self.__question_audio = self.__dict__['question_audio']
                del self.__dict__['question_audio']
            return self.__question_audio

    @ql.log_function()
    def set_question_audio_value(self, value):
        if not isinstance(value, str) and value is not None:
            ql.log_warning("Can't update question_audio with non-str obj")
            ql.log_value("value", value)
            return None
        else:
            self.__question_audio = value
    #---------------    
    @property
    def question_image(self):
        try:
            return self.__question_image
        except AttributeError:
            if 'question_image' in self.__dict__:
                self.__question_image = self.__dict__['question_image']
                del self.__dict__['question_image']
            return self.__question_image

    @ql.log_function()
    def set_question_image_value(self, value):
        if not isinstance(value, str):
            ql.log_warning("Can't update question_image with non-str obj")
            ql.log_value("value", value)
            return None
        else:
            self.__question_image = value
    #---------------    
    @property
    def question_video(self):
        try:
            return self.__question_video
        except AttributeError:
            if 'question_video' in self.__dict__:
                self.__question_video = self.__dict__['question_video']
                del self.__dict__['question_video']
            return self.__question_video

    @ql.log_function()
    def set_question_video_value(self, value):
        if not isinstance(value, str):
            ql.log_warning("Can't update question_video with non-str obj")
            ql.log_value("value", value)
            return None
        else:
            self.__question_video = value
    #---------------    
    @property
    def answer_text(self):
        try:
            return self.__answer_text
        except AttributeError:
            if 'answer_text' in self.__dict__:
                self.__answer_text = self.__dict__['answer_text']
                del self.__dict__['answer_text']
            return self.__answer_text

    @ql.log_function()
    def set_answer_text_value(self, value):
        if not isinstance(value, str):
            ql.log_warning("Can't update answer_text with non-str obj")
            ql.log_value("value", value)
            return None
        else:
            self.__answer_text = value
    #---------------    
    @property
    def answer_audio(self):
        try:
            return self.__answer_audio
        except AttributeError:
            if 'answer_audio' in self.__dict__:
                self.__answer_audio = self.__dict__['answer_audio']
                del self.__dict__['answer_audio']
            return self.__answer_audio

    @ql.log_function()
    def set_answer_audio_value(self, value):
        if not isinstance(value, str):
            ql.log_warning("Can't update answer_audio with non-str obj")
            ql.log_value("value", value)
            return None
        else:
            self.__answer_audio = value
    #---------------    
    @property
    def answer_image(self):
        try:
            return self.__answer_image
        except AttributeError:
            if 'answer_image' in self.__dict__:
                self.__answer_image = self.__dict__['answer_image']
                del self.__dict__['answer_image']
            return self.__answer_image

    @ql.log_function()
    def set_answer_image_value(self, value):
        if not isinstance(value, str):
            ql.log_warning("Can't update answer_image with non-str obj")
            ql.log_value("value", value)
            return None
        else:
            self.__answer_image = value
    #---------------    
    @property
    def answer_video(self):
        try:
            return self.__answer_video
        except AttributeError:
            if 'answer_video' in self.__dict__:
                self.__answer_video = self.__dict__['answer_video']
                del self.__dict__['answer_video']
            return self.__answer_video

    @ql.log_function()
    def set_answer_video_value(self, value):
        if not isinstance(value, str):
            ql.log_warning("Can't update answer_video with non-str obj")
            ql.log_value("value", value)
            return None
        else:
            self.__answer_video = value
    #---------------    
    @property
    def module_name(self):
        try:
            return self.__module_name
        except AttributeError:
            if 'module_name' in self.__dict__:
                self.__module_name = self.__dict__['module_name']
                del self.__dict__['module_name']
            return self.__module_name

    @ql.log_function()
    def set_module_name_value(self, value):
        if not isinstance(value, str):
            ql.log_warning("Can't update module_name with non-str obj")
            ql.log_value("value", value)
            return None
        else:
            self.__module_name = value.lower()
    #---------------
    @property
    def author(self):
        try:
            return self.__author
        except AttributeError:
            if 'author' in self.__dict__:
                self.__author = self.__dict__['author']
                del self.__dict__['author']
            return self.__author
    
    @author.setter
    def author(self, value):
        print("Once author is set, is not to be changed")

if __name__ == "__main__":
    # Test suite for Development of QuestionObject
    json_encode = {
        "id": "2025-03-12 09:17:37.728579_47d39d7b-37ff-461b-aeec-ca52e36c101d",
        "primary_subject": "miscellaneous",
        "subject": [
            "miscellaneous",
            "western history"
        ],
        "related": None,
        "question_text": "Some Question Text",
        "question_audio": None,
        "question_image": None,
        "question_video": None,
        "answer_text": "Some Answer Text",
        "answer_audio": None,
        "answer_image": None,
        "answer_video": None,
        "module_name": "western civilization ii: renaissance to present",
        "author": "Original"
    }