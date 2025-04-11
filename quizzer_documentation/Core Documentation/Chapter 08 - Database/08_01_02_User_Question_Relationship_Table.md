# User_Question_Relationship_Table

### Description
The User_Question_Relationship_Table tracks the individual relationship between users and question-answer pairs within the Quizzer platform. Each record represents a unique user-question pairing and stores critical data for the memory retention algorithm, including revision streak, scheduling timestamps, circulation status, and eligibility. This data enables personalized learning sequences and optimized review scheduling based on each user's specific interaction history with individual questions. Further information about the user relationship with individual knowledge units will be recorded amongst the records in the [[08_01_03_Question_Answer_Attempts_Table]]


### Fields
Primary_Key = user_uuid + question_answer_reference 
Foreign_Key = user_uuid (links to User_Profile_Table), question_answer_reference (links to Question-Answer Pair Table)

| Key                            | Data Type    | Description                                                                                                                                           |
| ------------------------------ | ------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| user_uuid                      | String(uuid) | Identifier of the user                                                                                                                                |
| question_answer_reference      | String       | Reference to the specific question-answer pair                                                                                                        |
| revision_streak                | Integer      | Number of consecutive successful revisions of this question                                                                                           |
| last_revised                   | date_time    | Timestamp of when the user last reviewed this question                                                                                                |
| predicted_revision_due_history | String(Json) | {timestamp: prediction} where both are date_time's the values indicating the predicted date of the model %% This isn't implemented just yet though %% |
| next_revision_due              | date_time    | Calculated timestamp of when this question should be reviewed next                                                                                    |
| time_between_revisions         | Double       | Coefficient used in calculating optimal spacing between revisions                                                                                     |
| average_times_shown_per_day    | Double       | Calculated frequency of presentation based on scheduling algorithm                                                                                    |
| is_eligible                    | Boolean      | Whether the question is eligible to be placed into circulation                                                                                        |
| is_module_active               | Boolean      | Whether the module containing this question is currently active                                                                                       |
| in_circulation                 | Boolean      | Whether the question is currently in active rotation for review                                                                                       |

### Usage Notes
1. The circulation status of questions is determined by the [[09_03_Question_Circulation_Selection_Algorithm]] using the boolean fields in this table
2. The next_revision_due timestamp is calculated by the [[09_02_Memory_Retention_Algorithm]].
3. Questions can be in various states derived from the combination of boolean fields:
    - In circulation and eligible (active questions)
    - Not in circulation but eligible (reserve bank)
    - Not eligible (resides in database but temporarily excluded from learning)
4. The Memory_Retention_Algorithm continually updates these records based on user interactions recorded in the Question_Answer_Attempts_Table

This table serves as the core data structure enabling personalized spaced repetition for each user-question combination, allowing the system to optimize learning schedules based on individual performance patterns.