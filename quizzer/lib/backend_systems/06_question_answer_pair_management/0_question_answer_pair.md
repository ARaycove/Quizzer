The question_answer_pair_management/ contains four objects, all related to the creation, updating, review, and validity of the content on Quizzer


# QuestionAnswerPairManager()
General object for the retrieval of question answer pairs for use in the main program.

# QuestionGenerator()
Contains all functionality related to the creation of new question answer pairs, this object holds all such methods as needed by the AddQuestionPage() in the UI.

# QuestionReviewManager()
For Admin and contributor use, this object holds all the methods and functionality required to ensure that all content on Quizzer is reviewed and all content meets content standards as defined in the review methodology document: https://docs.google.com/document/d/1yGZNGnybC_uzwItcm0lm_-0-u12EE-ep/edit?usp=drive_link&ouid=109560521241055628480&rtpof=true&sd=true

QuestionReviewManager makes direct calls to the server and does require an active connection, this will manage which questions go up for review out of all the questions currently in the review backlog.

# QuestionValidator()
Contains the functionality to ensure that all data inputs are in the proper form and structure, as SQLITE does not support JSON, this object ensures that JSON strings are in the proper format before being stored in the database.