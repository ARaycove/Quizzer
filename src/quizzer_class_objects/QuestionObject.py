from datetime import datetime, timedelta, date
import pickle

class QuestionObject():
    '''
    Core class for Quizzer, this object holds a question and answer pair along with data that describes how it relates to core concepts and subject matters.

    - media related fields should be file paths to the associated media file, not a blob file itself. Future iterations will experiment with embedding media directly into the object for easier storage.
    '''
    def __init__(self,
                 author:            str,
                 question_text:     str     = None,
                 question_audio:    str     = None,
                 question_image:    str     = None,
                 question_video:    str     = None,
                 answer_text:       str     = None,
                 answer_audio:      str     = None,
                 answer_image:      str     = None,   
                 answer_video:      str     = None,
                 module_name:       str     = None,
                 id:                str     = None,
                 primary_subject:   str     = None,
                 subjects:          list    = None,
                 related_concepts:  list    = None
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
        self._author            = author
        self._build_question_object()
    def _calculate_question_id(self) -> dict:
        '''
        Generates the id for the inputted question object, only run if the QuestionObject does not already have an id.

        Unique id is determined by the current time and the author concatenated
        '''
        current_time = str(datetime.now())
        return current_time + "_" + self._author
    
    def __str__(self):
        result = f"QuestionObject @ Memory:{id(self)}\n"
        for key, value in self.__dict__.items():
           result += f"{key:25}|{value}\n"
        return result

    def __eq__(self, other):
        if not isinstance(other, QuestionObject):
            return False
        return self.__dict__ == other.__dict__
    
    def _build_question_object(self):
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
        "question_text": "What political movement did resentful elite Indians eventually organize as a result of discrimination in the colonial system during the imperial era 1800's?",
        "question_audio": None,
        "question_image": None,
        "question_video": None,
        "answer_text": "The Indian Independence Movement",
        "answer_audio": None,
        "answer_image": None,
        "answer_video": None,
        "module_name": "western civilization ii: renaissance to present",
        "author": "47d39d7b-37ff-461b-aeec-ca52e36c101d"
    }

    test_data = QuestionObject(
        author          = json_encode["author"],
        id              = json_encode['id'],
        primary_subject = json_encode["primary_subject"],
        subjects        = json_encode["subject"],
        question_text   = json_encode["question_text"],
        answer_text     = json_encode["answer_text"],
        module_name     = json_encode["module_name"]
        )

    print("str print out of QuestionObject:")
    print(test_data)
    
    print("Testing save and load of Question Object")
    with open("test.pickle", "wb") as f:
        pickle.dump(test_data, f, protocol=pickle.HIGHEST_PROTOCOL)
        print(f"    Test Object Saved Successfully")

    with open("test.pickle", "rb") as f:
        test_data_duplicate = pickle.load(f)
        print(f"    Type of loaded object: {type(test_data_duplicate)}")
        print(f"    Type of saved object:  {type(test_data)}")
        
    print(f"Checking Equivalency: {test_data == test_data_duplicate}")
    if test_data != test_data_duplicate:
        print(test_data)
        print(test_data_duplicate)
