# Feature Extraction
Given the question data set, we need to extract multiple features:
-  The vectorized question data itself
-  The K-nearest neighbors for each question record (which questions are immediately similar)
-  K-means clustering, applying the cluster_id to the question record
# Question Selection Algorithm
After a user answers a question and submits a response, which question in the database should be presented next?

# Data Synchronization Algorithm
As the size and scale of Quizzer grows, so will the amount of data that exists. This algorithm will determine what data is needed by the user's client device and synchronize that data with the central database.