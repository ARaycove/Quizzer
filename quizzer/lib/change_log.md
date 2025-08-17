# Update 1.0.4
Some of these were in patch updates 1.0.3 and below, so there.
* [x] Admin states that new questions added to already activated modules are NOT being added to the his profile
  * Likely the check was removed by the old coding agent, and the removal was not caught by the admin who did that refactor
  * Fix would be to find the old check logic, see where it's being called, and add to the login initialization process function, probably immediately after the verify all tables and during the final checks before the login init returns and allows the app to move to the Home Page
  * [x] validateAllModuleQuestions was only being called IF the user added a question of there own. thus any new questions were not being validated. Individual modules would be validated but only on the first activation of the module. I have now added in the validate call during the login initialization after the sync works are initialized. If the user logs 
* [x] Fill in the blank validation needs to be updated to not run typo check on number values
  * for example if answer is 165, and the user enters 166, the answer is WRONG, however typo check validates 166 as acceptable enough and marks it correct.
  * Could add a "strict" tag to a fill in the blank question, where if the string doesn't match exactly then it's wrong otherwise leniancy is granted
  * Or have it evaluate strictly if the answer value isdigit()
  * [x] Validation has been updated such that if the primary answer can be cast into an integer then the provided answer is checked as strict equivalency against the actual answer, this does leave out the synonym checking logic for integer answers
* [x] Changed review system to always review new question additions before reviews edits to existing questions
* [x] user settings are resetting on login and on new device
  * [x] removed isDatabaseFresh check and passing of parameter, fetchAll now handles timestamp for filtering as the only source of truth - did not fix the issue
  * [x] updated outbound sync to refuse pushing default setting records
  * [x] rewrote the ensure default settings exist function
  * [x] rewrote the batch upsert function
  * [x] Moving the verify function seemed to solve local reset issue, but new device not syncing persists. . .
  * [x] Optimize table interactions by creating a central function that verifies all tables during login initialization removing the calls from each individual table file
    * All table verification is now done ONCE during the login initialization
  * [x] All table helpers that read or write data are updated to take in txn or db
  * [x] Potential issue in inbound sync mechanism where update does not persist outside of the inbound sync call, solution will be to restructre the inbound sync such that
    * [x] All calls to fetch data is done at once asynchronously (saving time)
    * [x] all batch upserts to the tables are done together as a single transaction, ensuring everything is committed together
* [X] some module names are not getting normalized, make sure all functions that deal with module_name normalize the moduleName
  * [X] multiple functions in modules_table.dart did not normalize, they do now
  * [X] checked if the question answer pair table was normalizing
  * [X] checked inbound sync to normalize inbound data
  * [X] checked outbound sync to normalize outbound data
* [x] Fix update_flags review system, does not validate that the question being flagged still exists in the database
* [x] Circulation should remove access revision score 0 questions from circulation
in offline and does not have the sync mechanism enabled this check does not need to be run.
* [x] Selection worker keeps spitting the same true/false question back at me
  * True/False Validation was not getting the data it needed correctly, it was being passed a boolean value, and it expected an integer, but did not error out. . .
* [x] updated fill in the blank validation to lower case string inputs before checking for similarity, as this was causing "not Q" and "Not q" to evaluate to False for equivalency
* [x] Latex elements left aligned with $single dollar signs$ need to have more top padding to prevent overlap
    * Top padding of 8 was to small try 12
    * adjust LaTex font style to maintain the line sapcing between two LaTex texts (Should be resolved with top padding)
* [x] synonym adding in the add question page causes crash, if you tab out or lose focus of the synonym edit whilst it is blank, we get a crash "Concurrent modification during iteration: _Set len:1
    * Fixed focus change crash
    * when adding a synonym to a fill in the blank question, focus is immediately given to the synonym field to be added 
- Logs show that the network issue for compare_question.dart triggered, and handled the network error without crashing the program. Good!

# What is this?

This is the change_log, whenever the team (myself currently) goes to build the next update, we will pull all changes made from the update_plans.md. Anything that was actually done, and checked off will be moved to here, where those details will remain permanently. This is a working document, and update_plans.md is also a working document.

New updates will be posted to the top of the file. At time of writing the current version is 1.0.3 and is being updated with patch 1.0.4