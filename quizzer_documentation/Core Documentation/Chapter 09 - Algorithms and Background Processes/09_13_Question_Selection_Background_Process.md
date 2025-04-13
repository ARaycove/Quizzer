There are a few primary functions involved how the main interface works.

Generally the process can be succinctly described, a user will be presented with a question, when they answer the question the response will be recorded in the [[08_01_03_Question_Answer_Attempts_Table]], then a new question will be selected to presented to the user, repeating the process.

This background process will handle everything involved in deciding what question should be presented next at that moment and serves the purpose of ensuring that computation necessary for this selection process does not interrupt the flow of the UI [[05_05_Home_Page]].

To accomplish this we will do the following
1. Generate a asynchronous queue type object (so it is named in Python, dart is different)
2. Run a check on that queue object to get its length. If the length is < 10, then proceed, otherwise sleep for 8 seconds (Avoiding unneccesary checks)
3. Get the difference between 10 and the current length of the queue
4. Select that many questions by running the  [[07_14_getNextQuestionForReview()]] function n amount of times

With this structure, the UI can fetch items from this queue object to be presented to the user, while a separate thread can deal with selection and other more time consuming behavior.