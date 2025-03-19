# Goals
################################
# How we will save and commit the data currently running
# Coroutine to routinely commit the state of Quizzer's Database

# commit the UserProfile of the user after every answer, placing the UserProfile state in a queue, which the central coroutine will pick from to make updates to the DB (This could be a lot of requests, but really it takes a fraction of second to both load and commit a state)

# Locking mechanisms so co-active instances don't cause race conditions
#