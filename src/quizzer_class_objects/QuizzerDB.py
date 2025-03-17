import pickle
import json
import datetime
from QuestionObject import QuestionObject, util_QuizzerV4ObjDict_to_QuestionObject

class QuestionObjectDB():
    def __init__(self):
        self.__all_question_objects = {} # stored by id: QuestionObject

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
