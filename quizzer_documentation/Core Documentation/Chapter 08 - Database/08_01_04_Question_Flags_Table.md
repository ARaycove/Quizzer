### Description
The Question_Flags_Table records instances where users flag question-answer pairs that may have issues or require review. Each record captures the specific question-answer pair that was flagged, the user who submitted the flag, their comment explaining the issue, and the exact timestamp of the flag submission. This table serves as a quality control mechanism allowing users to provide feedback on problematic content.

### Fields

Primary_Key = time_stamp + user_uuid + qst_ans_reference 
Foreign_Key = user_uuid (links to User_Profile_Table), qst_ans_reference (links to Question-Answer Pair Table)

| Key               | Data Type    | Description                                                                 |
| ----------------- | ------------ | --------------------------------------------------------------------------- |
| time_stamp        | date_time    | Exact time when the flag was submitted                                      |
| user_uuid         | String(uuid) | The identifier of the user who submitted the flag                           |
| qst_ans_reference | String       | Reference to the question-answer pair being flagged                         |
| comment           | String       | User's explanation of the issue with the question-answer pair               |
| review_status     | String       | Current status of the flag review (e.g., "pending", "reviewed", "resolved") |
| reviewed_by       | String(uuid) | Identifier of the administrator who reviewed the flag (if applicable)       |
| resolution_notes  | String       | Notes on how the flag was addressed after review                            |

### Usage Notes
1. Flags are created through the Home Page interface when users identify issues with question-answer pairs
2. Each flag requires a comment explaining the specific concern with the content
3. Administrators regularly review flagged content and update the review_status accordingly
4. Resolution may involve editing the original question-answer pair, removing it from circulation, or dismissing the flag