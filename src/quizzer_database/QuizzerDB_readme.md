# The Quizzer Database is an Object Oriented Database

So we're going to design everything for these sub-objects to take only exactly what information is required, and worry about ensuring it all passes correctly higher up the chain, if we try to pass the reference for the DB directly we get circular import errors

# We can have higher objects import from lower objects

So going to need an import chain 
if Quizzer needs the QuestionObject class directly it can import it through QuizzerDB which imported it from UserProfile, which imported it directly from the QuestionObject.py file. So it is an actual chain

# Quizzer
- imports QuizzerDB only
