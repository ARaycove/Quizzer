# Question-Answer Pair Tables

### Description
The Question-Answer Pair Table stores individual question-answer pairs produced during content generation tasks. Each record represents a single question with its corresponding answer, metadata, and review status. Questions are categorized into three core types (Selection-Based, Input-Based, and Interactive) with specific fields for each type. This table tracks the complete lifecycle of question-answer pairs from creation through review to eventual deployment to users.

### Fields
Primary_Key = time_stamp + qst_contrib
Foreign_Key = citation (links to Citation and Source Material Table)

| Key               | Data Type    | Description                                                                                                                |
| ----------------- | ------------ | -------------------------------------------------------------------------------------------------------------------------- |
| time_stamp        | date_time    | Exact time of initial entry (time of question generated)                                                                   |
| citation          | String       | The citation for the source material from which the question-answer pair is derived                                        |
| question_type     | String       | Type of question (multiple_choice, true_false, matching, sorting, fill_in_blank, short_answer, hot_spot, diagram_labeling) |
| question_elements | String(JSON) | The main question body                                                                                                     |
| answer_elements   | String(JSON) | The main answer body                                                                                                       |
| qst_contrib       | String(uuid) | Participant_id of the person who generated the question                                                                    |
| qst_reviewer      | String(uuid) | Participant_id of the person who reviewed the qst-ans pair                                                                 |
| has_been_reviewed | bool         | Indicates that the qst-ans pair has been reviewed by a human being                                                         |
| flag_for_removal  | bool         | Indicates the reviewer claimed the qst-ans pair should be removed                                                          |
| completed         | bool         | Indicates whether all tasks necessary to produce an entire question-answer pair are completed                              |
| module_name       | String       | The name of the module this question belongs to                                                                            |
| concepts          | String(CSV)  | List of key terms and concepts associated with the question-answer pair                                                    |
| subjects          | String(CSV)  | List of subject matters to which the question-answer pair relates                                                          |

### Selection-Based Question Fields
| Key              | Data Type    | Description                                                          |
| ---------------- | ------------ | -------------------------------------------------------------------- |
| options          | String(JSON) | For multiple choice: Array of possible answers                       |
| correct_indices  | String(JSON) | For multiple choice: Array of indices for correct answers            |
| matching_pairs   | String(JSON) | For matching questions: Array of {left: String, right: String} pairs |
| correct_sequence | String(JSON) | For sorting questions: Array of indices in correct order             |

### Input-Based Question Fields
| Key                | Data Type    | Description                                                              |
| ------------------ | ------------ | ------------------------------------------------------------------------ |
| correct_answer     | String       | For fill-in-blank: The exact correct answer                              |
| acceptable_answers | String(JSON) | For fill-in-blank: Array of acceptable variations of the answer          |
| answer_format      | String       | For fill-in-blank: Format specification (e.g., "number", "date", "unit") |

### Interactive Question Fields
%% Not Implemented, coming back to this %%

| Key         | Data Type    | Description                                                                                       |
| ----------- | ------------ | ------------------------------------------------------------------------------------------------- |
| target_area | String(JSON) | For hot spot: {x: float, y: float, radius: float} defining correct area                           |
| labels      | String(JSON) | For diagram labeling: Array of {id: String, text: String, correct_position: {x: float, y: float}} |
| tolerance   | Float        | For interactive questions: Acceptable margin of error for position matching                       |
