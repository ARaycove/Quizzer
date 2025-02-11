# Adaptive question addition
- Questions are added based on an average daily questions figure.
- The user sets this number
## Problem
- If the user lapses and starts to answer less than average, then questions become overwhelming, if the user doesn't reduce the daily average, they fail to keep up with the flow.
## Solution
- Have quizzer only add questions when the user finishes answering all questions for the day.
- Quizzer when it detects there are no more eligible questions will introduce 1 new question. The user will answer this 1 question twice, then a new one will get introduced. At this phase, the user will keep getting new questions until they are done with that sessions. 
- Those new questions will then increase the average accordingly, if the user fails to keep up with all the new questions added, the average will reduce until the user is able to keep up again. Thus the average daily figure will automatically adjust to the usage pattern.
- On motivated days, the user will get tons of new content, but on slower days, no new content will be introduced.
## Implementation
- Adjust home, to only call to add new questions when it detects as empty, but not on startup
- Adjust circulation function so target is always 1 when it launches