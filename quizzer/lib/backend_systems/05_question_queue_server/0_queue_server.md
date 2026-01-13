The Queue Server comprises 3 core singleton Objects

*Worker indicates an object that runs on a loop and is connected to the SwitchBoard
*Manager encapsulates a specific set of functions into one object for cleaner code

# UserQuestionManager()
The UserQuestionManager holds all methods related to the creation of new User question records, and functionality related to getting and updating those records
    - Will be further abstracted into a UserQuestionUpdater()

# CirculationWorker()
The CirculationWorker determines what questions are in the user's knowledge base at any given moment, and well add or remove questions to and from active circulation for that user. Such a system prevents Quizzer from overloading the user by trying to teach them everything everywhere all at once.

# PresentationSelectionWorker()
The PresentationSelectionWorker determines out of all the circulating questions in the user's active knowledge base which one to present at this very moment. The total circulating questions could be in the hundreds, thousands or tens of thousands. This system allows us to algorithmically find the right question at any given moment.
