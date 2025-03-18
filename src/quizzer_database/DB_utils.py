import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import QuestionObject

def util_QuizzerV4ObjDict_to_QuestionObject(json_dict: dict):
    return QuestionObject.QuestionObject(
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
    print("Nothing Here Yet")