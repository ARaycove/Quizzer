import pickle
import json
import datetime
from QuestionObject import QuestionObject, util_QuizzerV4ObjDict_to_QuestionObject

class QuestionObjectDB():
    # Cool Dunder Methods
    def __init__(self):
        self.__all_question_objects = {} # stored by id: QuestionObject
        self.__subject_index        = {} # {"subject_class": "question_id"}
        self.__concept_index        = {} # {"concept_class": "question_id"}
        self.__module_index         = {} # {"module_name": "question_id"}
    def __add__(self, other):
        raise NotImplementedError("In Testing, remove raise statement to test")
        if isinstance(other, QuestionObject):
            # If use add operator DB + QuestionObject, should add the question object to the 
            self.add_new_QuestionObject(other)
            # FIXME Should also add this to the main QuizzerDB object
    # Index build functions
    def _construct_subject_index(self):
        raise NotImplementedError("I'm not done yet, calm down")

    def _construct_concept_index(self):
        raise NotImplementedError("I'm not done yet, calm down")
    
    # Index access functions
    def get_list_of_subjects(self):
        raise NotImplementedError("I'm not done yet, calm down")
    
    def get_list_of_concepts(self):
        raise NotImplementedError("I'm not done yet, calm down")
    
    def get_questions_by_subject(self, subject_name: str):
        raise NotImplementedError("I'm not done yet, calm down")
    
    def get_questions_by_concept(self, concept_name: str):
        raise NotImplementedError("I'm not done yet, calm down")

    # Add or Delete QuestionObject's
    def add_new_QuestionObject(self, question_object: QuestionObject):
        self.__all_question_objects[question_object.id] = question_object

    def delete_QuestionObject(self, question_object_id: str):
        del self.__all_question_objects[question_object_id]

    def get_QuestionObject(self, question_id: str) -> QuestionObject:
        return self.__all_question_objects[question_id]

    def debug_write_db_to_json(self):
        """
        Write database contents to a JSON file for debugging purposes.
        Creates a debug representation of all question objects.
        """        
        # Create debug representation of the database
        debug_data = {
            "timestamp": datetime.datetime.now().isoformat(),
            "total_questions": len(self.__all_question_objects),
            "questions": {}
        }
        for question_id, question_obj in self.__all_question_objects.items():
            # Extract key properties for debugging
            question_obj: QuestionObject
            question_data = question_obj.__dict__
            debug_data["questions"][question_id] = question_data
        
        # Generate filename with timestamp
        timestamp = datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = f"questiondb_debug_{timestamp}.json"
        
        with open(filename, 'w') as f:
            json.dump(debug_data, f, indent=4)
        
        print(f"Debug data written to {filename}")
        return filename

class QuizzerDB:
    def __init__(self):
        self.QuestionObjectDB = QuestionObjectDB()

    def commit_QuizzerDB(self):
        with open("QuizzerDB.pickle", "wb") as f:
            pickle.dump(self, f, protocol=pickle.HIGHEST_PROTOCOL)


if __name__ == "__main__":
    print("Testing QuizzerDB Implementation")
    # Create a QuizzerDB instance
    db = QuizzerDB()
    print(f"Created new QuizzerDB instance: {db}")
    with open("TestQuestionObject.pickle", "rb") as f:
        test_question: QuestionObject = pickle.load(f)
        print(f"Loaded test question from file: {test_question.id}")
    
    # Add the question to the database
    db.QuestionObjectDB.add_new_QuestionObject(test_question)
    print(f"Added question to database: {test_question.id}")

    print(f"Testing direct access to added question:")
    
    print(f"Testing direct update of individual QuestionObject parameters")

    # Run the following comment to conver the old db to the new db
    # with open("../system_data/question_object_data.json", "r") as f:
    #     old_data:dict = json.load(f)
    #     print(f"Old Data loaded successfully. . .\n Now applying util function to all question objects in old data")
    # i = 0
    # for key, value in old_data.items():
    #     try:
    #         qo = util_QuizzerV4ObjDict_to_QuestionObject(value)
    #         i += 1
    #         db.QuestionObjectDB.add_new_QuestionObject(qo)
    #     except:
    #         print(f"conversion failed on id: {key:.50}")

    # db.commit_QuizzerDB()

    # with open("QuizzerDB.pickle", "rb") as f:
    #     db = pickle.load(f)
    # db: QuizzerDB
    # db.QuestionObjectDB.debug_write_db_to_json()
