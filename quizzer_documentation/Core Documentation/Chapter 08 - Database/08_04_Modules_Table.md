# Modules_Table

### Description

The Modules_Table stores information about curated sets of question-answer pairs that are grouped together as learning units. Each module represents a cohesive collection of related knowledge that users can activate or deactivate as a complete set. The module system provides an organizational layer above individual question-answer pairs, allowing for structured learning sequences and direct user control over which knowledge domains they engage with. This table maintains the metadata for each module while tracking relationships to questions and user activation status.

### Fields

Primary_Key = module_name Foreign_Key = creator_id (links to User_Profile_Table)

|Key|Data Type|Description|
|---|---|---|
|module_name|String|User-friendly name for the module (unique identifier)|
|description|String|Brief explanation of the module's content and purpose|
|primary_subject|String|The dominant subject classification represented in this module|
|subjects|String(CSV)|Complete list of all unique subjects covered by questions in this module|
|related_concepts|String(CSV)|Complete list of all unique concepts/key terms represented in this module|
|question_ids|String(CSV)|Array of all question_ids belonging to this module|
|creation_date|date_time|The exact time when the module was created|
|creator_id|String(uuid)|Reference to the user who created the module|
|last_modified|date_time|The exact time when the module was last updated|
|total_questions|Integer|The number of questions contained in the module|

Note: The module activation status (is_active boolean) is stored in the User_Profile_Table rather than in this table, as activation status is user-specific and not an inherent property of the module itself. This approach allows different users to have different sets of active modules.

### Relationships

- Each Question-Answer Pair belongs to exactly one module
- User activation status for modules is tracked in the User_Profile_Table
- The creator_id field links to the User_Profile_Table to identify who created the module
- The question_ids field contains references to the Question-Answer Pair Table

### Usage Notes

1. When a module is created, the system automatically aggregates the subjects and related_concepts fields by analyzing all questions assigned to the module
2. The primary_subject is determined by frequency analysis of subject classifications across member questions
3. The total_questions field is maintained by the system and updated whenever questions are added to or removed from the module
4. The last_modified timestamp is updated whenever the module properties are changed or the question composition is altered