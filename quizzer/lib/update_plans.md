Bug Fixes are important, they are however a part of the backlog, and there will always be plenty of bugs to fix, for now. Anything listed under "## bug fixes" can be pushed to the next update, or included as a patch update at any point.

We are using the semantic versioning system n.n.n ==> Major.Minor.Patch

Where major updates break compatability with previous versions
Minor updates add features and other visible changes
Patch updates are for bug fixes that don't add features, or for optimizations that the user does not see


The goal of this update is to:
1. Ensure the login and logout flow works properly, that any asynchronous workers are closed, that the state of the app is completely reset for a new login attempt
2. Ensure no keys are exposed, and security is up to standard
3. Fix build issues


## Implementation TODO:
* [x] logout, closes processes and kills the app (include splash screen)
  * [x] Will need to rigoursly test logout/login/logout/login cycle works and doesn't break the system. Currently there is some kind of issue regarding if we logout, existing processes are not closed properly. This is related to the login/logout process
    * [x] Logout function does not properly return
      * Perhaps the issue is that the menu page, immediately sends us back to the home page allowing us to login again before the logout cycle is done.
      * [x] added await to the menu_page.dart await session.logoutUser() Further testing required at this point.
      * [x] Outbound sync worker did not return stoppage, stuck waiting, thus added extra outboundSyncComplete signal for the stop function.
        * Potential delay, if sync worker is in its 30 second wait cycle when logout is clicked.
        * could solve with a new waiting while loop, and an additional method. The method will wait 30 seconds then flip the sentinel value breaking the loop, this would leave us open to flipping the sentinel value ourselves:
        
* [] update login page with
  * [] login with google
  * [] login with facebook
  * [] login with github
  * [] login with . . . (other social accounts as possible)

* [] Add a reset user password page
  - Currently there is no way for a user to properly reset their password, if they forget their password they get locked out of their account for good.
  * [] Figure out how to validate user session within the app? Since there is no website domain for quizzer to utilize, so if there's a way to do this without a web app, that would be better
  - Perhaps we can figure out how to send an email out that when clicked opens a specific page on the app itself, thus the only way to access the reset user password section of the app is through the email link?
  * [] reset password page with authentication setup (webpage?) 

* [] Security sweep
  * Ensure all environment variables and access is secure and nothing is exposed that shouldn't be exposed.
  * Currently supabase.client has hardcoded access URL and such

## Resolve bugs relating to login flow:

# Update ?.?.?: User Profile Page
The user profile page serves as the first set of features to be fed into the question accuracy prediction model. The following series of updates will setup the data flow such that we can easily get this data and feed it into the model

If you have other suggestions for easily quantifiable metrics that could be included in the user profile page, please do say something.

* [] Need to create the User Profile page, On this page the user will be prompted to fill out there profile with all the fields listed in the user_profile table.
* [] Profile picture should be at the top of the User profile page. 
  * [] It should be a round portrait frame, 
    * [] make sure you write this in such way that it's easy to add on decorations and frames around the profile that will be able to be unlocked through a future planned badge and achievement system.
  * [] around the profile picture, we will have a progress indicator that wraps around the profile picture
    * [] when they 100% fill out the profile there should be some form of easter egg, like the bar turning golden or some shit like that. Don't really care, just want the psychological effect of an award being given to the user in some capacity.
* [] Good UI/UX for filling this out,
  * [] Perhaps a button that when clicked gives a slide-show style presentation that pops up just what the user hasn't filled out yet, so they don't have to be bothered with filling this information out.
* [] Info button -> "Why are you asking me for all this personal data? And Why should I give it to you?"
  * [] I would like some kind of optional info button / FAQ whatever, that can alleviate the data privacy concerns a user might have.If we want user's to provide their data to improve model accuracy we must give them good reasons and be persuasive.

# Update ?.?.?: Training Data Collection:
For this update we need to rebuild the stat collections metrics.
* [] Update supabase with the question_vector column
  * [] Update the ml_pipeline to push the question vector back to supabase

* [] Every module will need to be updated such that we track overall performance on a module by module basis. These stat block will become vectors which will feed into the accuracy prediction model.
  * [] we will need a user_module_performance_table.dart sql table made to house this data

* [] SubmitAnswer will need to be updated to capture the correct features
  * [] Repurpose question_answer_attempts table with each field being a "feature" we collect
  - The goal is that whenever a question is answered, Quizzer generates a complete training data point (approximately)
  - See quizzer_v04/quizzer_documentation/Core Documentation/Chapter 09 - Algorithms and Background Processes/09_00_Feature_Outline.md for details on the full vector output expected

* [] Update ML pipeline to pull all training data from supabase
  * [] Export model and write a function that takes the input vector as input, and outputs the result of the model
  * [] Write a specific function that generates the input vector for running the model locally, taking in just the question_id, and db_txn as input parameters
  * [] Write unit tests to ensure sub-system works
  
Once this is all set up and Quizzer is generating the training data needed for the model we can begin work on rebuilding the UI/UX to be more "pretty" and usable

# Update ?.?.?: UI Overhaul
For this update we will focus on building new widgets and rebuilding old pages so they are less janky and overall have a proper UI/UX design.

## Module system rework
For the planned circulation algorithm, the module system will work as the method by which user's "seed" their initial profile. Thus this update will focus on optimizes the display modules page and fix any bugs relating to this system.

The design of the display_modules page should be such that
- User's can easily and intuitively find any topic they might be interested in (module names are written as topic matters)
- Easy to navigate the modules, this is a challenge because the number of modules will only ever get larger, so we need a scalable display that can adapt on the fly
  * [] Rewrite the admin utility that allows the groupings to be changed by the admin, after the display_module redesign. Admin should be able to reorganize the structure of the module cards, so if a module is misplaced an admin should be able to put it in the correct location
- Keep module card design if possible, we want the user to have immediate access to the module description and meta-data about that module

* [] Search and filter modules functionality
* [] Update the module card to display percentage of questions in module in rotation (completion status)
* [] Add option to incorporate Graphical backgrounds to individual modules for added visual flair (Admin access only)

## Expansion of math_keyboard and math_expressions, initial changes to UI
Not sure what's going on with the team that built the math_keyboard, permissions say modification and distributions is fine. I am considering taking the field and completely rebuilding it. Names and all, and package it internally inside quizzer as a "global widget":

- Goal is to be able to type math expressions using a keyboard, and provide a built in field that actively renders that latex
  - desmos.com has a proper keyboard that can enter any kind of notation ever. Essentially we want the blank widget to have a keyboard that allows the user to easily enter math notation and thus allow for more complicated mathematics questions

- Current iteration write a TeX string, which means anything goes, and should be able to update easily based on the full library of TeX, but the iteration is hyper-limited to only some

- Then for question validation that tex string should then be evaluated down to value. So we neeed:
  * [] ability to type any mathematical notation through a custom keyboard
  * [] ability to evaluate any mathematical notation down to a number

Second to address would be the update to the math_expressions library to allow evaluation of the 
* [] Update TeXParser
  * converts TeX string $\frac{x}{y}$ to computer readable expression
* [] Update ExpressionParser
  * takes a parsed TeX string and evaluates the result, by directly injecting variables with real values

## Rebuild Add Question Page
The current add question page is janky and hard to use. Though it is working.

We want to scrap it, and rebuild it as a WYSIWYG (What you see is what you get) style interface
- [] Question type selection
- [] Based on question type selected the interface will adapt (perhaps just by graying out incompatible components, MCQ won't get an option to add fill in the blank elements)
  - That is unless you want to spend the extra time to make this dynamically detect what kind of question_type it is on the fly.


## Additional User Settings:
* [] User Settings: auto-submit multiple choice questions (default behavior is to auto-matically submit the selected option)
  * this settings would disable the auto-submit behavior and make it so the user needs to hit the submit answer button on multiple choice questions

## Tutorial Update:
This update will focus on adding info icons and tutorial to Quizzer to introduce new  user's to the platform, there are a lot of moving parts and a tutorial goes a long way to help a new user figure out what the hell is going on.
## Tutorial Points to Touch on:
### Home Page Display
#### Flag Question Button
* [] Initial user will have no questions so tutorial will have to bring up a mock flag for the user to interact with
#### Question Display
* [] Math.tex is a horizontally scrolling, user will need to shift-scroll to see full expression or on mobile will have to swipe on it to see the whole equation.
#### Menu

## Admin tools expansion
Some extra tools to make it easier to comb through and review the state of questions in Quizzer
## Review Module Questions Tool
### Features
* [] Review Questions button in admin tool section of the modules page
* [] Counter at top to show progress of the list of questions in the module
* [] Arrow selection to skip to n# question in the module (for if admin doesn't get through all n questions)
* [] Pull in review panel tool interface
  * [] delete option
  * [] edit option
  * [] approve edit option (No direct push, require additional layer of validation from main panel)
  * [] Should pull the question_id locally and pull the question record from the server directly

## Bug Fixes:
* [] Some question answer attempt records ARE NOT syncing and triggering an RLS violation. . .
  * Appears to be intermittent, as many attempt records do get synced
* [] Circulation worker does not properly remove excess new questions, allowing too many new questions to overload the user. Should have some kind of mechanism that will remove only revision score 0 questions from circulation
* [] Math field does not expand to fit the what's entered into it

* [] Math validation should not allow the question to be entered as the answer (assuming the question is to transform the equation into some other form)
  * if userAnswer matches exactly the question, then it should not allow it to work
    * but if the correctAnswer is basic, then this doesn't fly
    * Perhaps some way to determine how many steps away the userAnswer is from the correctAnswer
    * has to at least be similar
    * apply evaluation + similarity? Yes I think this is the way,
      * similarity score must be greater than threshold AND evaluate correctly
  * This would be for factor(xyz)
  * evaluation function would evaluate both the same factored and non-factored version
  * so data structure needs to be updated. . .?
    * But this needs to be a more automatic determination

* [] Matrix latex elements with fractions inside, formatted fraction elements need padding on top to prevent overlap

* [] User States: "Android version needs some bottom margin on pages, preventing widgets from getting partially hidden."
  * snackbar pop-ups and margin cutoff on android are blocking the use of the next question button and submit answer buttons. Adding a bottom margin the height of the snackbar would remove this issue

* [] User States: Occasionally we get an app crash if I close my phone, then when I reopen the app I return to an error screen

## Other minor changes
* [] Synonym fields in the add question interface should also allow for math expressions
* [] True False Button options need to be bigger and more tactile, right now they are tiny
* [] Add \pm option to the math keyboard
  * [] do testing on evaluation function to ensure validation works with \pm
* [] Refactor Outbound sync to:
  * First gather all records from all tables that are unsynced ALL AT ONCE
  * Future.wait / gather all records to be pushed and push them in a batch asynchronously
  * Once the overall payload is back, check all values, and clean up accordingly
* [] Add ability to navigate using just the keyboard
  * [] number keys select options, if press 1 selects first option (or de-selects)
  * Navigation of the app should be possible without needing the mouse (assuming we are on a desktop)
* [] Next Question and Submit Answer should always float at the bottom of the screen, rather than be part of the main DOM
  * [] fill in the blank widget updated
  * [] multiple choice question widget updated
  * [] select all that apply widget updated
  * [] sort order widget updated
  * [] true false widget updated
* [] Should autofocus to the Next Question button when it appears
  * [] fill in the blank widget updated
  * [] multiple choice question widget updated
  * [] select all that apply widget updated
  * [] sort order widget updated
  * [] true false widget updated
* [] Add font-size settings to settings page
  * [] font-size for math elements
    * [] additional info icon to explain that math font size is larger due to exponents and readability
    * [] add setting value to settings page
    * [] add setting value to table
  * [] font-size for everything else
    * [] add setting value to settings page
    * [] add setting value to table
* [] User Setting: Shrink or Wrap options with default Wrap for math related latex. If Shrink the font size of a latex element will shrink to fit the screen, if wrap the latex element will wrap over to a new line to avoid cutting off text
* [] Fix Environment variables (Credentials should be stored securely)
* [] overhaul adding images, allow an option to choose from existing images in the system or to upload a new image (this will help prevent duplicating the same image file many times over)
* [] copy paste image support for add question interface
* [] Add setting and option to display next revision day project after answering a question
* [] Need to update QuizzerLogger such that I can trigger a level specific logging on a file by file basis

# Update ?.?.? Rebuild Selection and Circulation algorithms:
This update will introduce the internal machine learning model that will allow Quizzer to improve dynamically as more data comes
Deadline: New Years (after/during taking the Machine Learning Class)

See quizzer_documentation for details on the model design

## Define our model [ ]

### Model Definitions

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

# Update ?.?.? Academic Archive:
This update will be critical for further model optimizations and for adding an extra layer of validity to Quizzer

We are focused on three core categories in Academic Taxonomy,
**Keywords/Concepts**, **Subject/Fields/Major**, **Source Citations**

In order to allow for training of better models, we need to classify questions by their concept(s) and subject(s). A question may have multiple concepts and multiple subjects that it covers or even just one of each. For each of these we need to add functionality to the Admin Panel so we have the tooling to provide to our non-technical team to be able to add to and contribute to this archive.

## Keywords and Concepts definitions table
### Define the SQL table where this information gets stored
  Here a "keyword" and a "concept_label" are identical in meaning

  This table will be relatively simple storing {keyword: "<name>" and article: "<article>"}. The article will be a markdown document that can be loaded and rendered as such. Having this information provides us the capability to add features like a wiki section of the app that allows users to step outside the quizzer loop and just read the information they are looking for.

  * [ ] Need to define the sql table for this
  * [ ] Need to add a section to the admin panel allowing our admins to
    * [ ] submit keyword records
    * [ ] update keyword records with wiki articles
### Define the Relational Table
  Here we will define a table that links a question_id to an array of keywords
  * [] question_id | keyword | 
    - Very simple table, for every keyword associated with the question_id we will have a single record
    * [] Create an index for the SQL table that allows for O(1) look up times for faster queries, index by question_id

### Provide a tool in the admin panel
  Here we need a tool that will look for question records that have not been classified whatsoever and present them for classification. I expect extensive work on this, as the total number of concepts will grow into the tens of thousands in length. So we need some optimal way to allow our team who uses this tool to easily look up relevant concepts, assume the user is not able to recall off the top of their heads what the concept is.

This then lays the groundwork for setting up both the archive of wiki articles detailing extensively the base of human knowledge, and gives us the tooling needed to first generate the labels by hand, then use that information to train a ML classifier to automatically classify questions with ease. Once such a model for that is developed we can use it in conjunction with the admin tool for classification.

## Subjects
### Define the SQL Table for subject definitions:
* [x] The SQL table is already defined

### Admin tool
* [x] The admin tool already exists to provide subject definitions
  * [] Optimize the tool and do any redesign work necessary

### Define the relational table:
* [] question_id | subject
  - Much like the keywords relational table, the purpose of this table is to store what question has what subject labels
  * [] Ensure we have an index by question_id for quick O(1) Lookup times

## Citations
The purpose of citations is to have an archive of all material, citations table should include:
- Complete valid citation
- The actual content being cited should be stored in the table

If the actual content being cited is not stored in the archive, it defeats the purpose of storing this information, as citations might exist, but the source material is missing, making the citation effectively pointless. The hope is that by having this information, a future generative model can be created that can produce educational content on the fly based off real accurate, verified primary and secondary sources.
### Define the SQL table:
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

# Update ?.?.? Additional Question Types:
In this update we will be adding new question types to increase the variability of the platform. More types of questions should result in a more interactive platform and expand the range of things Quizzer can teach to people including the effectiveness of such

## Coding blocks
question_type == "coding"
Add a new question type coding

This question type will prompt the user to write some code snippet (small or large) in a given programming language.
The app should then be able to evaluate that the could snippet is correct for the given language. Since this requires special validation, it will be it's own question type

## Speech Questions
new question_type == "language"
- speech to text, say the word on the screen
- due to unpredictability, there will be an attempt count, say 3 tries to get it right before we flag it wrong
- This question type will allow for modules that quiz and help teach the user how to read and speak a language. My target module is for my daughter called sight words where the questions will be a sight word and she will have to say the word in order to answer it correctly
- this could extend to learning new languages for adults, where a module provides a word or phrase and the user has to speak that phrase to proceed.
- Development of this question type provides the speech-to-text functionality needed for the general accessibility update

## Short Answer Questions
question_type == "short_answer"
An extension of the fill in the blank evaluation. but more complex
Question is asked, and the user needs to type one or two sentences to answer the question. Then the platform will evaluate the answer on the fly. This is as challenging as it sounds

## Matching Questions
question_type == "matching"
Simple categorization question
Given category 1 - N, and options 1 - K, sort the options into the appropriate category bucket

Interactive drag and drop, make it fun

## Hot Spot Image Questions
An image will be provided to the user, and the correct pixel location(s) of the image must be clicked on by the user,

Such questions that fall into this question would include 
- "Given this map: Where is "Nepal" or "United States" or "Pakistan" or "Europe"
- Given an image of the engine bay, which part is the alternator
- Given an image of a cell diagram, where is the Smooth ER

This will be meant to be highly flexible and accomodate multiple fields of study

## Diagram Label Question
question_type = "diagram_label"

User is presented with an image of a diagram with empty labels and will be required to fill in the labels

## Electrical Wiring Question
question_type = "electrical_wiring"

User will be presented a diagram with devices on it, and will have to "wire it up" to the panel box.

For submission a custom effect could be a lot of fun, have them flip the panel box on, and if its wired correctly the lights go on. If not then the panel box blows/pops up just as it would in real life.

# Update ?.?.? Badges and Achievements:
badge and acheivement system needs to be built out, track question contributors and contribution by subject matter

The purpose of this update is to boost the level of engagement we can get off the platform. Engaged users will learn more and benefit more from the app.
- Question performance badges
- Contribution badges
- Unlocks in the User Profile Page
- Unlockable easter eggs

We will discuss again if we ever get here

# Update ?.?.? Accessibility:
Options and infrastructure for the disabled benefit everyone involved including those who are not physically or cognitively disabled.

## Speech to Text for the blind?

- Need a service feature that enables text to speech, take in String input, send to service, return audio recording. UI will use this api call to get an audio recording, receive it, then play it.
  - To test in isolation we will generate a few sentences and then pass to service, save the audio recording to a file, then use a different software to play it.
- Read Aloud button on home page that reads the question to the user. . .

## Spell and Grammar check
* [ ] Spell and grammer check should be added wherever relevant
  * [ ] Markdown editors
  * [ ] Add Question Page
  * [ ] Edit Question Dialogue







# Other ideas thrown at me:

subscribe to user question functionality, allow users to subscribe to specific creators, any questions they make get added to that user's profile automatically
