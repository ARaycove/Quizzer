# Question_Answer_Attempts

### Description
The Question_Answer_Attempts Table records all user interactions with question-answer pairs during learning sessions. Each record captures a single attempt by a user to answer a question, including their response, confidence level, timing metrics, and the knowledge context at the time of the attempt. This data serves as the foundation for the memory retention algorithm and personalized learning recommendations.

### Fields
Primary_Key = qst_ans_reference + participant_id 
Foreign_Key = qst_ans_reference (links to Question-Answer Pair Table)

| Key               | Data Type    | Description                                                                                     |
| ----------------- | ------------ | ----------------------------------------------------------------------------------------------- |
| time_stamp        | date_time    | Exact time of entry when the question was answered                                              |
| qst_ans_reference | String       | Reference to question-answer pair in question-answer pair table                                 |
| participant_id    | uuid         | The user's uuid assigned at login                                                               |
| response_time     | time_seconds | Time in seconds it took the user to indicate they had an answer                                 |
| response_result   | Float        | Confidence rating scale: Yes(sure)=1, Yes(not-sure)=0.5, No(not-sure)=0.25, No(sure)=0          |
| was_first_attempt | bool         | Indicates whether this was the first time the user attempted this question-answer pair          |
| knowledge_base    |              | A calculation that ranks how well the user is familiar with subjects/concepts at time of answer |
| qst_reference     | String(CSV)  | List of subjects and concepts classified for the answered question-answer pair                  |

Note: Some fields (like knowledge_base) can be derived later once classification is complete, as long as timestamp records are maintained for all interactions.