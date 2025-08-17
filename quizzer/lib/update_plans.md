Before we do anything we need a more streamlined approach to automated build and version updating

# Login Streamline update 1.1.0:

- update login page with
  [] login with google
  [] login with facebook
  [] login with github
  [] login with . . .
- reset password page with authentication setup (webpage?)

Implementation TODO:

[] Add a reset user password page

[] Figure out how to validate user session within the app
- Perhaps we can figure out how to send an email out that when clicked opens a specific page on the app itself, thus the only way to access the reset user password section of the app is through the email link?

[] Will need to rigoursly test logout/login/logout/login cycle works and doesn't break the system. Currently there is some kind of issue regarding if we logout, existing processes are not closed properly. This is a login issue, and goes under the minor update
## Bug Fixes
* [] synonym adding in the add question page causes crash, if you tab out or lose focus of the synonym edit whilst it is blank, we get a crash "Concurrent modification during iteration: _Set len:1
* [] Some question answer attempt records ARE NOT syncing and triggering an RLS violation. . .
  * Appears to be intermittent, as many attempt records do get synced
  * [] added conditional logging that logs the record trying to be pushed if a PostgrestException that contains -> <row-level security policy for table ""> is found with code: 42501

* [] Matrix latex elements with fractions inside, formatted fraction elements need padding on top to prevent overlap

* [] Latex elements that are too long need to wrap instead of being cut off at edge of screen

* [] If a user edits a question, it does not persist across logins, this means if I make an edit to something, the edit is pushed to the admin for review, but on next login, is reverted back to the unedited state. (Feature or Bug)?
  * I am contemplating removing the edit button from the main home page entirely, regular users would still have the ability to flag a question still sending it to the admin. flagging a question removes it from that users account until the question is reviewed upon which the question is restored to the user
* [] User States: "Android version needs some bottom margin on pages, preventing widgets from getting partially hidden."
  * snackbar pop-ups and margin cutoff on android are blocking the use of the next question button and submit answer buttons. Adding a bottom margin the height of the snackbar would remove this issue
* [] Circulation worker does not properly remove excess new questions, allowing too many new questions to overload the user. Should have some kind of mechanism that will remove only revision score 0 questions from circulation
* [] User States: Occasionally we get an app crash if I close my phone, then when I reopen the app I return to an error screen


## Miscellaneous Addition might get pushed to later updates
* [ ] Add the Quizzer Logo to the background of the home page (grayscale)
* [ ] Add font-size settings to settings page
  * [ ] font-size for math elements
    * [ ] additional info icon to explain that math font size is larger due to exponents and readability
    * [ ] add setting value to settings page
    * [ ] add setting value to table
  * [ ] font-size for everything else
    * [ ] add setting value to settings page
    * [ ] add setting value to table
* [ ] User Setting: Shrink or Wrap options with default Wrap for math related latex. If Shrink the font size of a latex element will shrink to fit the screen, if wrap the latex element will wrap over to a new line to avoid cutting off text
* [ ] Fix Environment variables (Credentials should be stored securely)
* [ ] User Settings: auto-submit multiple choice questions (default behavior is to auto-matically submit the selected option)
  * this settings would disable the auto-submit behavior and make it so the user needs to hit the submit answer button on multiple choice questions
* [ ] overhaul adding images, allow an option to choose from existing images in the system or to upload a new image (this will help prevent duplicating the same image file many times over)
* [ ] copy paste image support for add question interface
* [ ] Add setting and option to display next revision day project after answering a question
# Tutorial Update:

This update will focus on adding info icons and tutorial to Quizzer to introduce new  user's to the platform, there are a lot of moving parts and a tutorial goes a long way to help a new user figure out what the hell is going on.

# Automation Update:

This update will introduce the internal machine learning model that will allow Quizzer to improve dynamically as more data comes

Deadline: New Years (after I take the Machine Learning Class)

## Define our model [ ]

### Model Definitions

Define the specifics of the model and the vector embedding themselves

* [ ] Define input layer definitions
  * [ ] Task Prompt
    * [ ] Short statement that tells the model what needs to be done should always be a binary request as not to confuse the model
  * [ ] User Information
  * [ ] Context Window
* [ ] Define Number of layers
* [ ] Define Size of each layer
* [ ] Define Output Layer and Activation function
  * [ ] Output Layer
    * [ ] Will be float 0 to 1
    * [ ] Single output
    * [ ] Activation function will vary based on Task Prompt?
      * [ ] use the sigmoid activation for classification tasks
      * [ ] use raw value for relationship tasks (To what extent is x related to y)
      * [ ] for date outputs define custom activation function to convert float value to a date

### Storage:

Define how we could store the vector embedding in a sql table, or a json file? Maybe just a json file with the vectors stored inside

* [ ] Store as a raw json file that the model can use (This will prevent the model from competing for access to the DB, since this is a dedicated embedding that doesn't require constant access) Quizzer can load the embedding into memory on initialization and not have to keep loading the json file.
* [ ] Perhaps a detection mechanism to detect when the user has low memory on device and switch between memory storing during operation and loading the json and dumping memory when not used. Dynamic

### Training

Define how we will train the model, python has great tools so we can probably just train the model using python libraries and import it back into dart

* [ ] Unless we can do the back propogation in dart using the ml libraries for dart
* [ ] Have several existing LLMs pre-generate training data for question-subject classification
* [ ] Once we have training data set, train our blank randomized model with the generated training data
* [ ] Question Subject Classification

  * [ ] Using the model, train it with a prompt for classifying against subject and subject description labels

## Model Application:

* [ ] After the model has been trained for its first task, classifying question answer records by subject, run it and use it to classify all existing question answer pairs
  * [ ] Save the outputs for human verification later, human in the loop.
  * [ ] Develop framework to collect manually verified output for retraining the model on:
* [ ] Once Questions are classified, re-introduce the interest level setting to the either user settings page or the user profile page
  * [ ] This will be a display of a radar chart showing interest by subject relative to other interests
  * [ ] Have a section below the radar chart that allows the user to adjust and update what subjects interest them, manual reporting of interests

## Develop a user interest questionairre - optional for user

Optional questionairre that will set all interest levels based on a series of questions

* [ ] Develop the questions
  * [ ] Relational questions?
    * [ ] Pair grouping of subjects and ask which one they care about more
      * [ ] Would adjust the relative ranking of the two subjects (pushing one higher than the other by some degree)
      * [ ] You would rather watch football than play video games (0 - 10)
      * [ ] You would rather dissect a frog than write an essay on * (0 - 10)
  * [ ] Individual Questions?
    * [ ] Interest thresholds to unlock a more lengthy or targetted quiz?
      * [ ] Say we ask: "I enjoy working with my hands" and we get a 7, then we could follow up with "I would be happy working in a wood shop" . If we get 0 for the follow up, then don't inquire further about wood related trades, settings those intersts to 0, or some small value above 0 if they answer something else

## Other Miscellaneous Updates

* [ ] Add a back button for the review panels, requested by admin

# Academic Archive Update:

## Keyword definitions table

* [ ] Need to define the sql table for this
* [ ] Need to add a section to the admin panel allowing our admins to
  * [ ] submit keyword records
  * [ ] update keyword records with wiki articles

## Citation Entry Table

* [ ] Need to define an sql table
* [ ] Need to add a section to the admin panel allowing admins to:
  * [ ] Submit full citations, including the actual content of the cited material

## New Model Task - Binary Keyword Classification

* [ ] Generate inference data from existing llm models
* [ ] Train our existing model on new data-set
* [ ] Then have our model classify the existing questions
  * [ ] Store that data for manual human in the loop validation
  * [ ] Update active training loop system with new task
* [ ] All questions should now be classified by keyword and subject labels

## Home Page Info Icon

* [ ] To be displayed in the Answer Explanation AFTER a quesiton is answered
* [ ] Based on the classification results, display a list of keywords that the question covers
  * [ ] for each keyword, it should allow an info icon that when clicked gives a dialogue popup for the wiki of that keyword for further reading by the user. This means that if the user is curious the information is at their fingertips. If they are not, they are not bogged down in a wall of text.

# Additional Question Types Update:

## Math questions

- these will be manual input for answer, user is given a math equation to solve and must use the interface to enter their answer. There are no options, no hints. Validation is much needed for this.

- [ ] Custom Validation will need to handle multiple inputs that all could be correct, 2+ 3 = 3 + 2 for example, but this gets far more complicated so there has to be a way to validate equivalency of equations systematically. . .

## Speech Questions

- speech to text, say the word on the screen
- due to unpredictability, there will be an attempt count, say 3 tries to get it right before we flag it wrong
- This question type will allow for modules that quiz and help teach the user how to read and speak a language. My target module is for my daughter called sight words where the questions will be a sight word and she will have to say the word in order to answer it correctly
- this could extend to learning new languages for adults, where a module provides a word or phrase and the user has to speak that phrase to proceed.
- Development of this question type provides the speech-to-text functionality needed for the general accessibility update

## Short Answer Questions

## Matching Questions

## Hot Spot Image Questions

## Diagram Label Question

# Module Page Refinement Update:

* [ ] Allow the module page filter button to sort based on presets
* [ ] Add a search icon button that allows the user to fuzzy search existing modules
* [ ] Update the module card to display percentage of questions in module in rotation (completion status)
* [ ] Add option to incorporate Graphical backgrounds to individual modules for added visual flair
* [ ]

# Accessibility Update:

## Speech to Text for the blind?

- Need a service feature that enables text to speech, take in String input, send to service, return audio recording. UI will use this api call to get an audio recording, receive it, then play it.
  - To test in isolation we will generate a few sentences and then pass to service, save the audio recording to a file, then use a different software to play it.
- Read Aloud button on home page that reads the question to the user. . .

## Spell and Grammar check for those with learning disabilities?

* [ ] Spell and grammer check should be added wherever relevant
  * [ ] Markdown editors
  * [ ] Add Question Page
  * [ ] Edit Question Dialogue

# User Profile Page Implementation Update:

This update will enable the user profile, mainly for collection of information on the user that can be fed into Quizzer's internal AI model that has not been implemented yet.

The hope is that additional profile information can help make the model make more reliable and predictable assumptions thus providing a better learning experience

[] Radial display of user interests

[] decide whether settings of user subject interests is in the User Profile or the User Settings Page

# User Stats Page Refinement Update:

Experiement with different flutter chart libraries for better more engaging visuals in the stats portion

* [ ] Stat that tracks and displays the accuracy percentage by time of day
  * [ ] Will be 0hours to 24hours
  * [ ] by hour how accurate is the user (percentage correct)
  * [ ] Will need to track when questions are answered along with whether right or wrong
* [ ] Stat that tracks questions answered by time of day
  * [ ] Will be 0hours to 24hours
  * [ ] Likely update the existing questions answered to have 24 fields for hour of the day, incrementing the specific hour instead of the overall, then the overal can just be a sum of the 24 hour fields
* [ ]

## Suggestions:

fl_charts is garbage performance for large datasets

---

These updates are in the backlog no immediate plans

# Badges update:

badge and acheivement system needs to be built out, track question contributors and contribution by subject matter

- Question performance badges
- Contribution badges

# Other ideas thrown at me:

subscribe to user question functionality, allow users to subscribe to specific creators, any questions they make get added to that user's profile
