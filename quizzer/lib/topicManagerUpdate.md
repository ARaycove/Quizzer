* [x] Delete Display Modules Page
* [x] Remove Module Activation logic from eligible questions criteria
* [x] Remove any tables and logic regarding the old module system
* [] Refactor all user question access to a userQuestionManager() object
    - Done in part
* [] Refactor all question_answer_pair access to a QuestionAnswerPairManager() object
    - Done in part
* [] Fix CirculationWorker to initialize without module system
    - As stands the mechanism by which the first user records were created were ingrained in the module activation system, which is gone. So the Circulation Worker will now be updated to follow a new workflow; First All questions in the main table are loaded and a mainGraph is constructed, All the in circulation points are added, and all the non-circulating points are added, and all the non-circulating and not connected points are added. For an existing user there will be a in-circulation section, and new content will be added based on this, new content will be similar and connected to existing knowledge base. For a new user, no records will exist and nothing will be in circulation. The CirculationWorker in this case is already equipped to add a new question at random if there are no available questions attached to circulating ones(there is nothing circulating), however the records will not exist for a new user, so the fix to ensure that the CirculationWorker calls the UserQuestionManager() to add the new user record if it does not exist when deciding to place that question into circulation for that user. We will handle this through a try catch (SpecificError) only if we get the specific error that the record no exist will we go and create it, alternatively we can just check if the record exists before proceeding.
___________________________________--
After cleanup we need to update the ML pipeline and Data Tables
* [x] Add topics field to questions
