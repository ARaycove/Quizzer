# Main Interface 
Upon logging in the user should get sent directly into the main interface of the program. This interface will be the core Answer Questions behavioral task defined in [[03_06_Task_03_Answer_Questions]]. The user will be presented with a question, the center of the screen should be one large button, when clicked the interface should show an animation depicting a "card flipping over to the other side", where the card is the center button, then the answer to that question should appear. At the bottom of the page will be 5 buttons (Yes(sure), Yes(unsure), (?), No(sure), No(unsure)) to reflect the options in the Answer Questions behavioral task. Clicking the center button should bring up three additional options to select. (Did not Read Question Properly), (Not Interested In This), (Too Advanced for Me)
## Globals
Should make use of the following global variables for data consistency when switching pages, but also to help guide the program:
current_question = ...
- Keeps track of the current question the user is engaging with, that way it can remain there when navigating other menus. This should just be the question_answer_reference, also called the question_id. Which can be used to gather contents of the question-answer pair
has_been_flipped = ...
- Helps to keep track of whether the buttons should be enabled or disabled, while also serving to track whether the answer or question should be displayed on the central button
## Rule of Thumb
- Top Bar should use the navigation bar element
- Bottom Bar should use the bottom bar element
- Bottom and Top Bar should be static on the screen
- The center of the screen should scroll if the content of the box exceeds the height of the screen
- Home page should keep an internal record of quickly it took to answer the displayed question
	- The timer starts when the question is displayed
	- The timer stops when the center button is first flipped
	- When the timer stops the elapsed time is recorded and stored. This will be sent to the [[07_12_answerQuestionAnswerPair(status, elapsed_time)|answerQuestionAnswerPair(status, elapsed_time)]] as the second argument whenever the response is entered.
## Images
- Quizzer Logo should be displayed prominently in the center of the screen as the background.
- Quzzer Logo background should be grayscaled and blend into the black background
## Fields
- Flag Question TextField
	- This field appears when the flag question button is pressed, otherwise is not shown
## Buttons
- Menu button
	- Should redirect to the [[05_06_Menu_Page|Menu Page]]
	- Should be place in the top leftmost corner of the app-bar
	- Should not exceed 20px in height
	- Should use the hamburger menu icon
- Flag Question button
	- Should display a pop-up window that allows the user to flag the question as invalid. Pop-up window will have a textfield entry.
	- When submitted will enter the question-answer pair and the comment into the 
	- Should be located in the top rightmost corner of the app-bar
	- calls the [[07_13_flagQuestionAnswerPair(comment)|flagQuestionAnswerPair(comment)]] with the text that was entered
#### Response Buttons
All response buttons should follow a pattern where they begin as disabled, not allowing the user to click on them. The question should be displayed from the get_next question function. when the question button is clicked the animation will play and display the answer. At this point the answer is displayed the buttons should become enabled. Once an option is submitted the buttons should disabled again then the next question get's displayed.
- Yes(sure)
	- question-answer response button
	- Calls [[07_12_answerQuestionAnswerPair(status, elapsed_time)|answerQuestionAnswerPair(status, elapsed_time)]] with status code "yes_sure"
- Yes(unsure)
	- question-answer response button
	- Calls [[07_12_answerQuestionAnswerPair(status, elapsed_time)|answerQuestionAnswerPair(status, elapsed_time)]] with status code "yes_unsure"
- Other
	- question-answer response button
	- returns a pop window with three additional buttons, that take up 1/3 of the center button container ("Did not read the Question . . . Whoops", "This is TOO ADVANCED for me", and "Just not interested in learning this")
	- The pop up window will be separated into fifths, the first fifth will be the "Did not read the Question. . . Whoops" button with a green background matching the logo
	- The second fifth will be empty
	- The third fifth will be the "This is TOO ADVANCED for me" button with the same green background
	- The fourth fifth will be empty
	- the fifth fifth will be the "Just not interested in learning this"
- No(unsure)
	- question-answer response button
	- Calls [[07_12_answerQuestionAnswerPair(status, elapsed_time)|answerQuestionAnswerPair(status, elapsed_time)]] with status code "no_unsure"
- No(sure)
	- question-answer response button
	- Calls [[07_12_answerQuestionAnswerPair(status, elapsed_time)|answerQuestionAnswerPair(status, elapsed_time)]] with status code "no_sure"
- "Did not read the Question. . . Whoops" button
	- question-answer response button
	- Calls [[07_12_answerQuestionAnswerPair(status, elapsed_time)|answerQuestionAnswerPair(status, elapsed_time)]] with status code "did_not_read"
- "This is TOO ADVANCED for me" button
	- question-answer response button
	- Calls [[07_12_answerQuestionAnswerPair(status, elapsed_time)|answerQuestionAnswerPair(status, elapsed_time)]] with status code "too_advanced"
- "Just not interested in learning this"
	- question-answer response button
	- Calls [[07_12_answerQuestionAnswerPair(status, elapsed_time)|answerQuestionAnswerPair(status, elapsed_time)]] with status code "not_interested"