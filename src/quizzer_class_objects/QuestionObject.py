from datetime import datetime, timedelta, date
import pickle
import json
# Constructor fails if all question fields are None or all answer fields are None
class QuestionObject():
    '''
    Core class for Quizzer, this object holds a question and answer pair along with data that describes how it relates to core concepts and subject matters.

    - media related fields should be file paths to the associated media file, not a blob file itself. Future iterations will experiment with embedding media directly into the object for easier storage.
    '''
    ######################
    # Dunder Methods
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
        self.id                 = id                
        self.primary_subject    = primary_subject
        self.subjects           = subjects,             # None handled in build function
        self.related_concepts   = related_concepts      # None handled in build function
        self.question_text      = question_text
        self.question_audio     = question_audio
        self.question_image     = question_image
        self.question_video     = question_video
        self.answer_text        = answer_text
        self.answer_audio       = answer_audio
        self.answer_image       = answer_image
        self.answer_video       = answer_video
        self.module_name        = module_name.lower()  # None handled in build function
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
    ######################
    # Initial Build and Verification of Fields
    def _calculate_question_id(self) -> dict:
        '''
        Generates the id for the inputted question object, only run if the QuestionObject does not already have an id.

        Unique id is determined by the current time and the author concatenated
        '''
        current_time = str(datetime.now())
        return current_time + "_" + self.author

    def _verify_question_answer_fields(self):
        def _verify_question_field_present(self: QuestionObject):
            total_question_fields = 0
            if self.question_text != None:
                total_question_fields += 1
            elif self.question_audio != None:
                total_question_fields += 1
            elif self.question_image != None:
                total_question_fields += 1
            elif self.question_video != None:
                total_question_fields += 1
            return total_question_fields
        def _verify_answer_field_present(self: QuestionObject):
            total_answer_fields = 0
            if self.answer_text != None:
                total_answer_fields += 1
            elif self.answer_audio != None:
                total_answer_fields += 1
            elif self.answer_image != None:
                total_answer_fields += 1
            elif self.answer_video != None:
                total_answer_fields += 1
            return total_answer_fields
        answer_field_present    = _verify_answer_field_present(self)
        question_field_present  = _verify_question_field_present(self)
        if answer_field_present == 1 and question_field_present == 1:
            # print("QuestionObject Valid")
            pass
        else:
            raise Exception("QuestionObject must have at least 1 answer field and 1 question field to be valid")

    def _build_question_object(self):
        self._verify_question_answer_fields()
        
        # All question objects must have at least one subject matter to which it relates, if none is passed, default to miscellaneous
        if self.subjects == None:
            self.subjects = list(["miscellaneous"])
        elif isinstance(self.subjects, tuple):
            self.subjects = self.subjects[0]
        if self.primary_subject == None:
            self.primary_subject = self.subjects[0]
        for subject in self.subjects:
            subject = str(subject).lower()
        # All question objects has concepts and terms to which it relates, stored in an array, if nothing specified, then initialize to an empty array
        if self.related_concepts == None:
            self.related_concepts = []
        for concept in self.related_concepts:
            concept: str = concept.lower()
        # Modules are there to share batches of questions, and to quickly tell Quizzer what to include as eligible, overriding core functionality if desired.
        if self.module_name == None:
            self.module_name = "default_module" 
        # id is dependent on author:
        if self.id == None:
            self.id = self._calculate_question_id(self.author)
    ######################
    # Getter and Setter Safeguards
    # Prevent author from being changed
    @property
    def author(self):
        return self.__author
    @author.setter
    def author(self, value):
        print("Once author is set, is not to be changed")
        # Example to actual use this as intended
        # self._author = value


def util_QuizzerV4ObjDict_to_QuestionObject(json_dict: dict):
    return QuestionObject(
        author              = json_dict.get("author"),
        id                  = json_dict.get("id"),
        module_name         = json_dict.get("module_name"),
        primary_subject     = json_dict.get("primary_subject"),
        subjects            = json_dict.get("subject"),
        related_concepts    = json_dict.get("related"),
        question_text       = json_dict.get("question_text"),
        question_image      = json_dict.get("question_image"),
        question_audio      = json_dict.get("question_audio"),
        question_video      = json_dict.get("question_video"),
        answer_text         = json_dict.get("answer_text"),
        answer_image        = json_dict.get("answer_image"),
        answer_audio        = json_dict.get("answer_audio"),
        answer_video        = json_dict.get("answer_video")
        
    )


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

    test_data = util_QuizzerV4ObjDict_to_QuestionObject(json_encode)

    print("str print out of QuestionObject:")
    print(test_data)
    
    print("Testing save and load of Question Object")
    with open("TestQuestionObject.pickle", "wb") as f:
        pickle.dump(test_data, f, protocol=pickle.HIGHEST_PROTOCOL)
        print(f"    Test Object Saved Successfully")

    with open("TestQuestionObject.pickle", "rb") as f:
        test_data_duplicate = pickle.load(f)
        print(f"    Type of loaded object: {type(test_data_duplicate)}")
        print(f"    Type of saved object:  {type(test_data)}")
        
    print(f"Checking Equivalency: {test_data == test_data_duplicate}")
    print(f"Testing Access, getters and setters")
    test_data.author = "Change_Value"
    test_data.__author = "Change_Value"
    test_data._author = "Change_Value"
    print(f"Author Safeguard Works: {test_data.author == "Original"}")

    print(f"Testing Conversion Utility on old json database")
    with open("../system_data/question_object_data.json", "r") as f:
        old_data:dict = json.load(f)
        print(f"Old Data loaded successfully. . .\n Now applying util function to all question objects in old data")
    i = 0
    for key, value in old_data.items():
        try:
            qo = util_QuizzerV4ObjDict_to_QuestionObject(value)
            i += 1
        except:
            print(f"conversion failed on id: {key:.50}")

    print(f"Successfully converted all objects")