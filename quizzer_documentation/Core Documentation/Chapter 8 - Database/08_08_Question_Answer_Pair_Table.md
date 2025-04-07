# Question-Answer Pair Table

### Description
The Question-Answer Pair Table stores individual question-answer pairs produced during content generation tasks. Each record represents a single question with its corresponding answer, metadata, and review status. This table tracks the complete lifecycle of question-answer pairs from creation through review to eventual deployment to users.

### Fields
Primary_Key = time_stamp + participant_id (candidate key) 
Foreign_Key = citation (links to Citation and Source Material Table)

| Key               | Data Type   | Description                                                                                               |
| ----------------- | ----------- | --------------------------------------------------------------------------------------------------------- |
| time_stamp        |             | Exact time of initial entry (time of question generated)                                                  |
| citation          |             | The citation for the source material from which the question-answer pair is derived                       |
| qst_text          |             | Textual content of the question                                                                           |
| qst_image         |             | Image based question                                                                                      |
| qst_audio         |             | Audio based question                                                                                      |
| qst_video         |             | Video based question                                                                                      |
| ans_text          |             | Textual content of the answer                                                                             |
| ans_image         |             | Image based answer                                                                                        |
| ans_audio         |             | Audio based answer                                                                                        |
| ans_video         |             | Video based answer                                                                                        |
| ans_flagged       | bool        | Question flagged by user who is providing answers, question can't be answered from cited source material. |
| ans_contrib       |             | Participant_id of the person who generated the answer to the question                                     |
| concepts          | String(CSV) | List of key terms and concepts associated with the question-answer pair                                   |
| subjects          | String(CSV) | List of subject matters to which the question-answer pair relates                                         |
| qst_contrib       |             | Participant_id of the person who generated the question                                                   |
| qst_reviewer      |             | Participant_id of the person who reviewed the qst-ans pair                                                |
| has_been_reviewed | bool        | Indicates that the qst-ans pair has been reviewed by a human being                                        |
| flag_for_removal  | bool        | Indicates the reviewer claimed the qst-ans pair should be removed                                         |
| completed         | bool        | Indicates whether all tasks necessary to produce an entire question-answer pair are completed             |

Note: Contributors to the concept and subject classification are listed in separate tables, not within the Question-Answer Pair Table itself.