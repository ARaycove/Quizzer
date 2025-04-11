depending on status will do a few things:

will first record the current state in the [[08_01_03_Question_Answer_Attempts_Table]]

If the user uuid and question-answer-reference does not exist in the attempts table then we can accurately assume this is the first attempt

record the status

Once the record is made in the Attempts Table we need to call
1. [[07_14_getNextQuestionForReview()]] thereby fetching the next question to be displayed to the user this function will update the global variable current_question