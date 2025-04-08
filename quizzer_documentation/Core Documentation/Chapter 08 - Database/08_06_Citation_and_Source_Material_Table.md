# Citation and Source Material Table
### Description
The Citation and Source Material Table is responsible for storing academic material and the citation from which it originated. It also holds a record of who has reviewed and submitted which sections of a record.
### Fields
Primary_Key = citation
Foreign_Key = None

| Key               | Data Type                | Description                                                                                        |
| ----------------- | ------------------------ | -------------------------------------------------------------------------------------------------- |
| time_stamp        |                          | The exact time of entry into the table                                                             |
| citation          |                          | The exact and proper academic citation for the passage entered                                     |
| src_text          |                          | The textual content of the source material                                                         |
| src_image         | String (CSV, file_paths) | Any images associated with the passage                                                             |
| src_audio         | String (CSV, file_paths) | Any audio clips associated with the passage                                                        |
| src_video         |                          | Any video clips associated with the passage                                                        |
| has_been_reviewed | bool                     | Values of True indicate a human being a reviewed the source material and has deemed it to be valid |
| reviewer_id       |                          | the user_id of the person who reviewed the content to ensure granularity                           |
| submitter_id:     |                          | the user_id of the person who entered the original record                                          |
