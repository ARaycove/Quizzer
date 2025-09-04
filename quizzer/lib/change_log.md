# What is this?
This is the change_log, whenever the team (myself currently) goes to build the next update, we will pull all changes made from the update_plans.md. Anything that was actually done, and checked off will be moved to here, where those details will remain permanently. This is a working document, and update_plans.md is also a working document.
New updates will be posted to the top of the file. At time of writing the current version is 1.0.3 and is being updated with patch 1.0.4

# Update 2.2.1
* [x] added variables, p, n, r, k to the math keyboard

# Update 2.2.0

## Misc. Changes:

* [x] Added inboundSyncWorker.stop() call to the logout function
* [x] logout function was deleting persistent storage information, removed this removal code
* [x] cleaned up vibe coded comments (No longer using AI as an agent to write code)
    * removed logging statements related to fetching unsynced records. . . No longer needed at the moment, cluttered the logs. No I'm going to list everything i removed
* [x] Added typo check only string validation path, for specific cases (mostly for scientific terminology)
* [x] inbound Sync now based on pagination, and how many records exists locally, if 2000 question answer pairs exist locally, and 2500 exist on the server, then pagination request for all records will start at 1999-N,

## Data Pipeline
* Added a data pipeline script that fetches the question answer pair data, vectorizes that data, then performs k-means clusters and PCA analysis on that data.
  * Initial results are very interesting, effective, but a little noisy given the lack of data, it has effectively grouped all math, and most of history related topics togethers.

## Bug Fixes:
* [x] added call to login init:
  * [x] login init now ensures all modules referenced by questions have a corresponding module record
  * [x] login init now ensures that all questions that should be in the user profile are in the user profile
* [x] didUpdateWidget needs to be updated to not refresh the page on click, like we did for multi choice and fillInTheBlank
  * [x] select all that apply widget updated
  * [x] sort order widget updated
  * [x] true false widget updated
* [x] If a user edits a question, it does not persist across logins, this means if I make an edit to something, the edit is pushed to the admin for review, but on next login, is reverted back to the unedited state. (Feature or Bug)?
  * I am contemplating removing the edit button from the main home page entirely, regular users would still have the ability to flag a question still sending it to the admin. flagging a question removes it from that users account until the question is reviewed upon which the question is restored to the user
  * [x] Removed the edit question button from the home page, user's can still flag questions to mark them as needing rework
* [x] While values are being fixed the bug persists. Resolved, updates to didUpdateWidget and change to its conditions
    * Whenever focus is granted to the background widget (click off to a non-widget portion of the screen) it triggers the home page to rebuild it's question widget. This rebuilding of the question widget appears to what is causing the primary issue.
    * In order to resolve we need to figure out how to prevent the home page from rebuilding itself whenever a user clicks off into the background.
* [x] Values not being passed correctly for fill in the blank
  * [x] Refactored WidgetBlank, ElementRenderer and FillInTheBlank to pass a single controller, for fill in the blank questions the main question widget is now the single source of truth for which controller is passed to the WidgetBlank
  * [x] home page build method GestureDetector Jank was the source of the issue. It was setup to tell everything to drop focus. This how now been changed to pass focus to the background if we click off, this has removed the issue with all focus is lost and the TextFields clear themselves as a result. Maybe something deep is going on. But this was the cause of the JANK
  * If we lose focus then hit submit, a value of null is passed to the validation function
  * MATHFIELD:
    * [x] tab to submit answer works
    * [x] clicking directly on submit answer works (while the math keyboard is still up)
    * [x] clicking on background then on submit answer fails
  * TEXTFIELD:
    * [x] typing in blank works normally
    * [x] clicking off the blank causes the blank widgets textfield to clear
    * [x] clicking directly onto submit answer causes the blank widgets textfield to clear resulting in incorrect answer
* [x] User States they filled a blank, the app deleted the information they types then marked it wrong
* [x] User States that the correct answers are being duplicated in the Correct Answers portion of the fill in the blank question widget
  * [x] changed formattedCorrectAnswers to a set, to avoid duplication

# Update 2.1.0 - Variable and Focus 
## Content Changes
* [x] Need to add variables to the math keyboard z, a, b, c
  * [x] added to blank widget MathField
  * [x] added to add quesiton page editable blank MathField
  * [x] updated bindings in validation function to assign values to each

## Misc. Changes
* [x] Removed excess logging from question answer pair table file
* [x] Add the Quizzer Logo to the background of the home page (grayscale)

## Bug Fixes
* [x] Removed θ, unicode \theta does not parse correctly
* [x] Crash and jank fixed in add question page, editable blank is no longer trying to actively use the TeXParser and this validation is now handled by the parent widget as it should have been in the first place
* [x] Math Keyboard does not lose focus if we click off of it:
  * one is located in the widget blank, the other in the add question page
  * [x] Wrapped build method in a gesture detector so we can "focus" on the background
* [x] Refactored editable blank widget
    * set state error
    * single focus node on MathField Widgets
* [x] added conditional logging that logs the record trying to be pushed if a PostgrestException that contains -> <row-level security policy for table ""> is found with code: 42501
* [x] Cleaned up old logging statements from outbound_sync_functions.dart, only warnings and errors remain as logging statements
* [x] New questions added to modules that user's already have activated do not get added to the user profile UNLESS they reactivate the module
  * Likely there is an issue with the loop functional in the ensure all modules functionality, grabbing the wrong information probably
  * Deleted relic getModuleActivationStatus function from userProfile table file
  * Check function in module activation status table (already there)
  * updated imports
  * updated validateAllModule* function to properly use the function and actually check if the module is active
  * add validateAllModule* call to the login initialization process, user questions are ensured to exist on login and on new module activation
* [x] Math Validation fails to properly parse \frac{98}{1}
  * RESOLVE: expressions being passed in are valid through TexParser
    * Pre-parse them using the TexParser
    * value is Expression type -> convert to String
    * pass into ExpressionParser for Evaluation
    * Debug testing shows similarity score works ok: '\frac{78}{1} =? 78' -> Sim Score 0.166666...
      * conjunction of equivalency + sim score could provide the proper validation
      * more complicated math will require updates to the math keyboard and expressions validation and possibly the TeXParser as well
  * need to fix the parsing
  * math_keyboard provides a valid latex string
  * math_expressions expects it to be written out (98 / 1)
  
# Update 2.0.0 - Math Questions and Validation
Since this update is not backwards compatible we are updating as 2.0.0
## Core Changes:
* [x] Fill in the Blank Validation now includes updatable logic where the blanks are actively classified as to how they should be evaluated
* [x] math equation evaluation has been added as a validation type
* [x] Fill in the Blank question types now support math expressions for answers
    * This allows the blank question to be flexible, we can do string answers or math expressions
* [x] math_keyboard has been added for easy input for the user, user is now given the math keyboard if the blank requires a math expression, user does not need to know latex format to answer math questions in quizzer
This is not backwards compatible since prior to 2.0.0 there is no logic to parse math equations properly, thus prior version will break as a result.
## Bug Fixes
* [x] Latex elements that are too long need to wrap instead of being cut off at edge of screen
* [x] completion check crashes program, when empty string text elements are used as spacers in the add question interface
    * Updated logic to check for meaningful elements, thus empty string content does not automatically cause failure anymore
* [x] add question interface crashes if we leave the page, while the math keyboard is up
* [x] math keyboard stayed in focus even though we left the page
* [x] math keyboard crashed the program if we lose focus and the expression is invalid. -> add question page resolved

# Update 1.0.4 Patch Fix
Some of these were in patch updates 1.0.3 and below, so there.
* [x] Admin states that new questions added to already activated modules are NOT being added to the his profile
  * Likely the check was removed by the old coding agent, and the removal was not caught by the admin who did that refactor
  * Fix would be to find the old check logic, see where it's being called, and add to the login initialization process function, probably immediately after the verify all tables and during the final checks before the login init returns and allows the app to move to the Home Page
  * [x] validateAllModuleQuestions was only being called IF the user added a question of there own. thus any new questions were not being validated. Individual modules would be validated but only on the first activation of the module. I have now added in the validate call during the login initialization after the sync works are initialized. If the user logs 
* [x] Fill in the blank validation needs to be updated to not run typo check on number values
  * for example if answer is 165, and the user enters 166, the answer is WRONG, however typo check validates 166 as acceptable enough and marks it correct.
  * Could add a 'strict' tag to a fill in the blank question, where if the string doesn't match exactly then it's wrong otherwise leniancy is granted
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
* [x] updated fill in the blank validation to lower case string inputs before checking for similarity, as this was causing 'not Q' and 'Not q' to evaluate to False for equivalency
* [x] Latex elements left aligned with $single dollar signs$ need to have more top padding to prevent overlap
    * Top padding of 8 was to small try 12
    * adjust LaTex font style to maintain the line sapcing between two LaTex texts (Should be resolved with top padding)
* [x] synonym adding in the add question page causes crash, if you tab out or lose focus of the synonym edit whilst it is blank, we get a crash 'Concurrent modification during iteration: _Set len:1'
    * Fixed focus change crash
    * when adding a synonym to a fill in the blank question, focus is immediately given to the synonym field to be added 
- Logs show that the network issue for compare_question.dart triggered, and handled the network error without crashing the program. Good!

