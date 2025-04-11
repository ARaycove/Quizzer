# Subject_Concept_Classification_Results Table

### Description
The Subject_Concept_Classification_Results Table records user classifications of question-answer pairs against specific subjects or concepts. Each record represents an individual classification attempt, tracking which user classified which question-answer pair against which subject or concept, and what the result of that classification was.

### Fields
Primary_Key = time_stamp + participant_id + qst_ans_reference + item_queried 
Foreign_Key = participant_id (links to User_Profile_Table), qst_ans_reference (links to Question-Answer Pair Table)

| Key               | Data Type    | Description                                                                          |
| ----------------- | ------------ | ------------------------------------------------------------------------------------ |
| time_stamp        | date_time    | Exact time of attempt of task                                                        |
| participant_id    | uuid         | The uuid of the user that submitted this result                                      |
| qst_ans_reference | String       | The reference to the question-answer pair that the participant was asked to classify |
| item_queried      | String       | The subject or concept that the user was asked to classify against                   |
| result            | Integer[0,1] | The numerical result of the attempt [0, 1]                                           |
