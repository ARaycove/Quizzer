# New Language 
Quizzer to be rebuilt in DART, using Flutter framework with DART for the front-end. Writing the entire codebase in dart allows for three things, faster base language more performant with built in type safety. Dart is a compiled language. 2nd Dart backend semi-coupled with flutter front-end allows the entire application to run as a standalone app offline, and uses the user's device compute power rather than compute power that I myself as a solo developer would need to provide otherwise. 3rd Dart has a built-in integration with SQLite allowing the database structure to allow sync locally. For a scalable user base all I would need to solve after the initial build is to deploy a database server in which individual clients can sync to. Since SQL already has built in sync mechanisms, this should be too much to accomplish. Further processing will also be decoupled from the central UI experience. When introducing machine learning algorithms for classification, compute power can either be distributed to the clients, or as separate microservices assuming there is revenue to support a paid server to handle those computations.

# Rebuild the central quiz loop as a proper scientific experiment
## The Behavioral Task:
- User logs in
- Initial User is encouraged to express interest in various subject matters using the settings interface
- User is given a tutorial to explain the program
- Once tutorial questions are answered, a question is presented to the user
- The user provides an answer
- The user indicates they have answered
- The user is presented with the answer immediately providing feedback
- The user then submits an input (Correct(sure), Correct(Unsure), Wasn't paying attention, Incorrect(Unsure), Incorrect(Sure)) 5 possible responses
- Cycle repeats with a new question
## User Inputs with confidence ranking built in
- Correct (Sure)
- Correct (Unsure)
- Meh (Didn't read the question properly) Neutral throw away
- Incorrect (Unsure)
- Incorrect (Sure)
## Record Reaction times
- Question is presented
## Record Subject Matter of Question-Answer Pair
Each question-answer pair that is presented will need to be labeled with a list of subject matters and a list of core concepts to which they relate. Each label should also have a gradient 0-1 indicating how strongly it correlates with the question-answer pair.
## Record User Profile Data
Every User will have a profile that keeps a record of their usage data and more importantly metrics that record the user's prior knowledge. This prior knowledge ranking is predicated on the proper recording of subject and concept matter labels on individual question-answer pairs. Using the user's prior answer metrics of question-answer pairs we can derive what their current knowledge base is. The more the user uses the Quizzer platform the longer the more accurate we can predict what they currently understand and know. However it is impractical to assume that every user will be on the platform long enough to record this critical information. The working hypothesis though is that if this data goes uncollected the noise in the behavioral data from many users will cancel out so long as the user base has an even distribution of prior knowledge. The goal of Quizzer in this regard to find the relationship between prior knowledge and the ability to retain new information for an extended interval of time. A scenario in which you see information once, ponder it for a moment, then remember it for a year or longer without ever needing to revisit the material. Further we need to find the full exhaustive list of variables that play into the formula that governs our ability to retain memory. Upon working out this formula in all its neural complexity we can begin to tailor fit cirrculums for schooling to maximize retention whilst minimizing the amount of effort students need to put in to retain what they learn. In addition this would also allow students to learn at an accelerated rate compared to existing methods.

The primary goal of Quizzer to serve a central platform to both collect experimental data for analysis and model development but also provide immediate benefits to those who helped to provide that data. It would also be remiss to exclude that such a platform was orginally built for my benefit as a student who is seeking to maximize their learning rate and minimize the need to spend excess hours reviewing material at which I've already spend countless hours learning. There is nothing less frustrating then considering that hundreds or perhaps thousands of hours of effort might have been a complete waste because of tendency to lose retention of what we spend time learning. Afterall whatever is worth learning is worth retaining.

# A good experimental design will include all of the data necessary
# A good plan will allow for construction of core elements first, then supplementary data collection