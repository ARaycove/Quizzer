# Behavioral Tasks and Resulting Data Structures

### How is the data stored?
The Quizzer platform implements a hybrid local-central database architecture to optimize performance while maintaining data integrity. All behavioral task data is primarily stored in a relational database utilizing SQLite, which provides a lightweight yet robust solution integrated directly with the Dart programming environment. This implementation enables efficient local data operations while minimizing external dependencies.

As the project scales, the database architecture will transition to a distributed system with clear separation between local and central data repositories. Client applications will maintain local SQLite instances containing only the subset of data required for immediate user operations, while a centralized server infrastructure will house the complete dataset for analytical processing and machine learning operations. This synchronization pattern ensures data consistency while reducing bandwidth requirements and enabling offline functionality for end users.

### What about existing datasets?
The Quizzer platform's behavioral tasks have been deliberately designed with granularity as a primary architectural principle, facilitating seamless integration with pre-existing research datasets. This granular approach yields structured data that requires minimal preprocessing, enabling direct table joins during analytical operations without extensive data cleaning procedures. The field of educational technology and cognitive science offers numerous established datasets containing question-answer pairs and learning interaction data. Repositories such as Huggingface and Open-Neuro provide valuable resources that can be incorporated into Quizzer's analytical framework. For instance, these datasets could enhance validation algorithms that assess the quality of generated question-answer pairs or support unsupervised learning approaches where complementary models train iteratively against each other—the validation model providing feedback to refine the primary model. By maintaining consistent data structures and standardized classification systems across all behavioral tasks, the Quizzer platform maximizes interoperability with external research datasets, positioning the collected behavioral data as one component within a broader analytical ecosystem rather than an isolated repository.

### Open-Source Commitment
The Quizzer platform adheres to open-source principles in both its code architecture and data collection methodology. All behavioral task data collected through the platform will be published online under appropriate user agreements to ensure ethical usage while maximizing research accessibility. It is important to emphasize that Quizzer is fundamentally a research project designed to investigate the mechanisms of memory retention and optimize human learning processes. As such, the platform and its associated datasets are intended for non-commercial applications, with explicit prohibitions against monetization or for-profit redistribution. This commitment to open-source values aligns with broader scientific goals of transparency, reproducibility, and collaborative advancement of educational technology.

# Task_01: Source Material generation and classification
This grouping of behavioral tasks centers on the systematic extraction and processing of academic content into discrete "passages"—defined as self-contained textual units that maintain coherent meaning when isolated from their original context. While these passages may encompass various scopes ranging from individual paragraphs to entire chapters, the guiding principle is maximal granularity to facilitate precise learning unit construction.

The methodological approach maintains granularity as its core design principle, breaking down the content processing workflow into discrete operations performed by different participants. This design creates natural quality control checkpoints while minimizing cognitive load per participant. In this distributed workflow, one participant extracts passages from source texts, another identifies key terminological elements within those passages, and a third validates the source material's academic integrity. This separation of concerns ensures both procedural integrity and data quality while maximizing the potential for parallel processing across the participant network.
## Task_01a: Extract passages from Source Material
This task requires participants to analyze academic source materials and extract meaningful passages while recording their corresponding citations accurately. Source materials are restricted to academically rigorous content including peer-reviewed journal articles, university textbooks, doctoral dissertations, and other scholarly works commonly found in academic libraries. This constraint ensures Quizzer functions as a validated memory retention platform for factual knowledge typically acquired in accredited educational institutions.
### Procedural Guidelines
Participants should follow specific extraction guidelines to maintain content integrity. The optimal extraction points are natural section boundaries demarcated by headers, subheaders, or chapter divisions. Each chapter typically contains multiple potential passages that can stand alone while preserving semantic coherence. For works with less obvious structure, participants should identify conceptually complete units that maintain meaning when separated from surrounding text.

For content extraction, participants should digitally capture text through direct copying from electronic sources whenever possible to prevent transcription errors. For physical sources, participants may type content manually or use scanning technology, provided in the UI. All associated visual elements directly referenced in the passage should be included in the appropriate database field.

 %% Insert an example of a properly extracted passage with citation %% 
 %% Min-Max length guidelines on passages? %%
 %% Guidelines on if work cites other works %%

All citations will follow the BibTeX format as the platform standard. Different entry types (book, article, thesis, etc.) will use appropriate BibTeX fields while maintaining consistent formatting for database integration. In the task entry field, the parameters for the citation will be provided in discrete UI elements to ensure that the format is recorded properly. Each field will replicate as a field in the relational database structure. The data entry type will be a discrete set of 14 types (article, book, booklet, conference, inbook, incollection, inproceedings, manual, masterthesis, misc, phdthesis, proceedings, techreport, unpublished). There are standard fields for BibTex format, which are listed as follows: address, annote, author, booktitle, chapter, edition, editor, howpublished, institution, journal, month, note, number, organization, pages, publisher, school, series, title, type, volume, year, doi, issn, isbn, url.

Specific details of what these fields mean will be included in the UI of the task as tooltips.

See the following URL for more specific details on BibText: https://www.bibtex.com/g/bibtex-format/.
### Example Implementation

### Technical Implementation
This implementation stores content in a structured database with separate fields for textual content ("src_text"), images ("src_image"), audio ("src_audio"), and video ("src_video"), alongside the complete citation information. This structured approach to content acquisition creates the foundational knowledge repository that enables Quizzer's question generation processes while maintaining proper academic attribution and content integrity. 
## Task_01b: Key Term identification Task:
This task builds upon completed source material extraction (Task_01a) and focuses on identifying the significant terminology within each academic passage. Participants systematically extract key terms that represent core concepts, entities, and specialized vocabulary contained in the passage. This process creates a semantic framework that enables later classification, question generation, and relationship mapping across the knowledge base.
### Procedural Guidelines
- Participants will be presented with a previously extracted passage without seeing its citation information to prevent bias.
- Participants should read the entire passage carefully, identifying terms in the following categories:
    - **Technical concepts**: Specialized terminology specific to the academic field
    - **Named entities**: People, organizations, places, events, or other proper nouns
    - **Processes**: Named methodologies, systems, or procedures
    - **Theoretical constructs**: Models, frameworks, or paradigms
    - **Quantitative metrics**: Specific measurements, scales, or indicators
- Terms should be recorded as they appear in the text, maintaining original capitalization. However for core concepts, some interpretation may be required
- Multi-word phrases should be preserved when they represent a single concept (e.g., "educational data mining" rather than separate entries for "educational," "data," and "mining").
- Common words should only be included if they have specialized meaning within the context of the passage.
- Terms that appear multiple times within a single passage should only be recorded once

### Example Implementation
**Sample Passage:**
Educational data mining employs statistical, machine-learning, and data-mining algorithms over educational data. The Ebbinghaus forgetting curve, first documented in 1885, demonstrates how information is lost over time when there is no attempt to retain it. Modern implementations like the Leitner system leverage this understanding to create effective spaced repetition schedules. Researchers such as Murre and Dros confirmed the validity of Ebbinghaus's work in their 2015 replication study.

**Expected Output** (Not exhaustive)
"educational data mining", "statistical algorithms", "machine-learning algorithms", "data-mining algorithms", "Ebbinghaus", "Ebbinghaus forgetting curve", "Leitner", "Murre", "Dros", "spaced repetition", "Leitner system"

### Technical Implementation
The identified key terms from each passage will be transformed into a structured database representation. Rather than storing the raw list of terms, each unique key term across the platform is one-hot encoded into the database table for this task. For each record, these fields contain binary values (0 or 1) indicating whether that specific term appears in the associated passage.

The result of this task is a standardized set of terms that, when processed, create a semantic fingerprint of each passage through binary indicators. This approach enables efficient semantic searching, concept mapping, and relationship identification across the knowledge base.

## Task_01c: Review Records of Entry:
%% Introductory, descirbe the overall task and purpose %%
When a record is made the person submitting that information will have their id recorded, this is to track who has done what. This serves to help oust malicious actors, and gives us the ability to ensure that those reviewing a record for accuracy is not the same one that submitted the record.

The goal of this task is to read the source material entered and check it against it's citation. Ensure the source material is from the entered citation, if this fails the record should either be corrected or deleted. The reviewer should also ensure the citation provided is correct and of correct format.
 %% We haven't detailed the role of the reviewer in this task %% 
 
 %% Specific guidelines and implementation %%
%% Review citations are accurate %%
%% Review Key Terms derived %%
%% If review process fails, flag for removal otherwise flag as correct.  %%
%% Expected Results %%
If flagged for removal both the removal_flag becomes true and the has_been_reviewed field becomes True, otherwise only the has_been reviewed field is marked True

## Task_01: Data Structure - Source_Material Table
----- Citation and Source Material Table -----

Primary Key:    citation
Foreign Key:    None
time_stamp:         The exact time of entry into the table
citation:           The exact and proper academic citation for the passage entered
src_text:           The textual content of the source material
src_image:          Any images associated with the passage (will be an array of BLOBs)
src_audio:          Any audio clips associated with the passage (will be an array of BLOBs)
src_video:          Any video clips associated with the passage (will be an array of BLOBs)
has_been_reviewed:  boolean value to determine whether or not the record has been verified by a human being.
reviewer_id:        the user_id of the person who reviewed the content to ensure granularity
submitter_id:       the user_id of the person who entered the original record

| time_stamp | citation | src_text | src_image        | src_audio        | src_video        | has_been_reviewed | removal_flag | reviewer_id | submitter_id |
| ---------- | -------- | -------- | ---------------- | ---------------- | ---------------- | ----------------- | ------------ | ----------- | ------------ |
| date_time  | String   | String   | Json(file_paths) | Json(file_paths) | Json(file_paths) | bool              | bool         | uuid        | uuid         |

## Task_01: Data Structure - Source_Material_Key_Term Table
This table will record the results of the Key Term Identification task.
Each record should link a specific record in the Source Material Table.

Primary Key:        time_stamp + participant_id
Foreign Key(s):     time_stamp + qst_contrib (link to Question-Answer Pair Table)
-----Fields-----
time_stamp:             exact time of entry
participant_id:         the contributing participant_id
citation:               the citation, linking this table to the Source Material table
key_terms:              The result of the Key Term identification task, for every key_term, a new field will be created for this table. The value shall be 0 or 1 indicating presence or lack of presence of that key_term

| time_stamp | participant_id | citation | key_terms |
| ---------- | -------------- | -------- | --------- |
| date_time  | String(uuid)   | string   | 0 or 1    |

# Task_02: Generate question-answer pairs and provide classification for those pairs
This block of tasks will instruct the participant user to generate questions based on source material provided in task_01, generate answers to those questions, classify them based on subject matter and conceptual matter, and review each to ensure the question-answer pair is properly derived from the source material.

## Task_02a: Generate questions based on source material
As the first task progresses, participants will be tasked with reading the individual passages recorded. Only the source material will be shown without reference to the academic citation itself. The purpose of the citation is so Quizzer can properly give credit and or verify individual sources if news breaks that certain studies or sources have been discredited. There is the potential of multiple questions or phrasing of questions to occur, so the result of the entry for this task will be a list of possible questions, which may or may not include image data, audio, or video. The resulting data structure from this task will be an array, where each item in the array, is an array of length 4 [question_text, question_image, question_audio, question_video], the first item will be a string, the rest can be stored as BLOB in the SQL database where all this data will be stored. If image, audio, or video are not included a NULL value will be put in that position in the array as a placeholder.

An example of a passage where multiple questions can be derived is a history book that mentions a specific person, (birth-death year) and a simple description of what they did. In this one sentence we can extract the name of the person against what they did. When were they born? When did they die? What are the birth and death years of that person? What did so and so do? What are so and so known for? All of these are possible and acceptable outputs. 

The result is an additional column with an array of possible outputs

# Task_02b: Generate Answers to questions based on the source material
Once question(s) are generated for given passage, the participants will need to generate answers for the individual questions. The answer's provided will again be an array of length 4 [answer_text, answer_image, answer_audio, answer_video]. For answers only one answer is to be given for each question in the above array. If the question array is 5 items long, 5 answers must be generated to coincide.

Alternatively, we can spawn additional columns for every possible question to enter, but it does seem cleaner to have a single output column

# Task_02c: Subject and Concept Classification Task:
This task is relatively straightforward. A user will be presented with a question-answer pair along with either a subject or concept. At the beginning of the session the user will be told whether they will classify subjects or concepts for question-answer pairs. Subjects will be selected at random from a list 2080 academic field names. Located in the subject_data/subject_taxonomy.py file. Concepts selected to be compared will be derived from the Key Term identification Task.

This task will be self-paced, and proceed as follows
1. The participant will be presented with a question-answer pair, displayed at the same time. Alongside this will be a standard question. Does the question-answer pair above relate to the <"subject" or "concept"> (whichever they are currently classifying against subject matters or concept matters) <name_of_subject_or_concept>
2. Once the prompt is given the user will be presented with a scale, asking the user to rate on the scale how much the concept or subject matter relates. Given a 0 - 10 scale. With zero indicating a -1 and a 10 indicating a 1. With all possible gradients in between. This will give us a gauge of confidence alongside the accuracy response

- Concepts and Subjects will be derived from these results by summing up the weights of the results. A value > 0.5 will allow that subject to be placed into the list If further classification results cause this value to drop to val <= 0.50  then it will be removed from the list dynamically

# Task_02d: Validation and Manual Review
This task will be to do read and understand the prompted question-answer pair. Then to read the source material that is claimed in it's entry. If the reviewer deems that the question-answer pair is not properly derived from the source material the question-answer pair will be flagged for removal or modification. If the reviewer deems that they can modify the question-answer pair so it does properly derive from the source material they shall do so. Otherwise if the question-answer pair is non-sensicle and can't reasonably be modified it shall be flagged for removal. The user uuid of the reviewer will be recorded.

## Task_02: Data Structure - Question-Answer Pair Table
Table should have one record per question produced in our task. When the task is complete we will get an array of question entries, each item in the array should be entered here as individual records
Primary Key: time_stamp + participant_id (Is a candidate key)
Foreign Key: citation (Questions table links to Citation and Source Material Table)
-----Fields-----
time_stamp:     Exact time of initial entry (time of question generated)
citation:       The citation for the source material from which the question-answer pair is derived

qst_text:       textual content of the question
qst_image:      image based question
qst_audio:      audio based question
qst_video:      video based question

ans_text:       textual content of the answer
ans_image:      image based answer
ans_audio:      audio based answer
ans_video:      video based answer


concepts:       json_object - list of key terms and concepts associated with the question-answer pair
subjects:       json_object - list of subject matters to which the question-answer pair relates

qst_contrib:    participant_id of the person who generated the question
ans_contrib:    participant_id of the person who generated the answer to the question
qst_reviewer:   participant_id of the person who reviewed the qst-ans pair

has_been_reviewed:  boolean value, indicating that the qst-ans pair has been reviewed by a human being
flag_for_removal:   boolean value, indicating the reviewer claimed the qst-ans pair should be removed. (If this boolean is true, the question answer pair does not actually get removed, but rather placed in a different table)

completed:      boolean value to indicate whether or not all the tasks necessary to produce an entire question-answer pair are completed. This boolean will be used to prompt what question-answer pairs still need additional work, and what question-answer pairs are ready for display to user's.
<!-- - Note: contributors to the concept and subject classification will be listed elsewhere, but not inside the question-answer pair table itself -->

## Task_02: Subject_Concept_Classification_Results Table
Primary Key:
Foreign Key(s):
-----Fields-----
time_stamp:         exact time of attempt of task
participant_id:     the uuid of the user that submitted this result
qst_ans_reference:  The reference to the question-answer pair that the particpant was asked to classify
item_queried:       the subject or concept that the user was asked to classify against
result:             The numerical result of the attempt [0, 1]

| time_stamp | participant_id | qst_ans_reference | item_queried | result |
| ---------- | -------------- | ----------------- | ------------ | ------ |
| date_time  | uuid           | String            | String       | [0, 1] |

-----------------------------------------------------------------------------------------------------------
# Task_03: Usage data,
## Task_03a: Answer Question-Answer pairs Task
At this phase, we have collected academic citations, individual passages, probable question outputs, probable answer outputs for questions, subject classification data, and concept/key-term classification data. Now for users of the Quizzer platform the primary behavioral task will be to answer these questions and record the result. Unlike the subject/concept classification task, the answer here will be a binary Yes or No. However to indicate some level of confidence we will include 6 possible answers. Yes(sure), Yes(not sure), No(sure), No(not sure), did not read question properly before answering, and a final answer to indicate that the user is not ready for this material yet, or has no interest in learning it.

The first four answers should be the most common, either you know you answered it correctly or not, but you might feel a bit hazy on whether you were sure of yourself. For this reason, a sure and not sure option will be provided. However there are cases where you might prematurely answer the question with great confidence only to realize you did not properly read the question, in this case you were neither right or wrong, you answered a question that was not presented. So a middle option for this case will be presented. Two other possible conditions exist. The user is not ready to learn this material as it is out of order and the user understands they do not have the pre-requisite knowledge to properly understand the material provided. An option should be provided for this scenario. Finally it is possible that the question-answer pair just has no value or interest to the user, in which case an option to should be provided to indicate this sheer lack of interest. Given the complexity of possible states. We will have 7 possible answers. In the UI interface of the task 5 buttons will be presented. Two of the left will be Yes(sure), Yes(unsure), A middle ? button, No(unsure), No(sure). Pressing the question mark button will provide a prompt to input one of three edge cases, you did not read the question properly and thus gave a wrong answer, you do not care to see this question-answer pair, or you are not ready to learn this material yet.

All possible states will be recorded, for the lifecycle of Quizzer, providing a do not care response will remove that question from your active pool of questions, providing a is not ready response will place the question into the reserve bank with a lock preventing it from entering circulation for at least n days. n will have to be determined later.

Other data to be recorded during this task
- qst_ans_reference:    record the reference to which qestion-answer pair was attempted
- response time:        How long did it take from the time the question was presented for the user to select to view the answer
- response result:      The result given in the above description
- user_uuid:            the uuid given to the user of the platform
- attempt_number:       the nth attempt given by the user to the specific question-answer pair (this can be derived by sorting attempting by timestamp then counting, select time_stamp from table where qst_ans_reference = qst_reference)
- knowledge-base:       The current state of the user's knowledge (simple way to derive this is to get a summation of every subject and concept by number of times mentioned in this table for this user)

Using this response data, along with the context of the question-answered and the tracked state of the user's current knowledge at time of answer, we will feed this data into a model that will get the probability the user will be right or wrong in answering a given question given the present_context. When a user provides an answer to a question, the current state of the program will be recorded as an attempt and that record will be fed into the existing model, the model will then calculate "At what time (t) will the user's probability of being correct (p) be n%? For the sake of maximizing length of time between questions and avoiding scenarios where a question was given for review too late, n will be set at 99% probability. This means that approximately every 1 in 100 questions will not be able to be answered correctly. Machine learning techniques will be used to process the entire table of results in order to train and derive the mathematical model for this program. It should be revisited at exactly what the optimal percentage target should be.

A question does remain, do we need to actively record the entire state of the user's progress at the time of answer, or can we write an algorithm that derives the current state of the user's knowledge base at the time of answer. As I understand it, if all data and records have exact time stamps any subsequent statistics can be derived. For example if we want to get the total amount of times the user has seen concept x, we'd first get every question-answer attempt for that user, filtering out other user data. We then for every attempt get whether or not it correlates with concept x. Total those up for every record thats before or at the time_stamp we are working with. Which we can pre-filter out of the data. Filter out all attempts after the specified timestamp. Once the algorithm is developed to join all this data into a record. The record can be fed into the ML model we are training. Thus it stands to reason we do not need to duplicate any data so long as any time anything is done an exact time_stamp is recorded.

Since we know that response time and confidence are tightly correlated and causal, we can use answer_times as a measure of confidence as well. However confidence and accuracy are not causal and thus can't be relied upon as an indicator of whether or not the user will be correct or incorrect

 It should be heavily noted however that we need to understand the relationship between confidence and ability to retain information. It may be that low confidence rankings lead to forgetting sooner than higher confidence ratings. By accurately recording reaction times and confidence metrics we should be able to divulge the relationship between how confident a person is in their answer and how long they can retain that information. I would hypothesize that higher confidence scores lead to more long term remembrance of information.
## Task_03 Data_Structure - Answer_Questions_task_results
Primary Key: qst_ans_reference + participant_id
Foreign Key: qst_ans_reference

<!-- -----Fields----- -->
time_stamp:         exact time of entry
qst_ans_reference:  reference to question-answer pair in question-answer pair table

participant_id:     The user's uuid assigned at login
response_time:      Time in seconds it took the user to indicate they had an answer
response_result:    binary 0 - 1 confidence rating. Yes(sure), Yes(not-sure), No(not-sure) and No(sure)
was_first_attempt:  0 or 1, indicates whether the user answered with Yes(sure) or Yes(not-sure) on very first attempt of question-answer pair
- These fields can be derived later once classification is done, and is not necessary to gather initial results, so long as we have time_stamp records of everything

<!-- Beyond recording response time and response result, first attempt, everything else can be joined into a specific record from other tables -->
knowledge_base:     A calculation that ranks how well the user is familiar with varying subjects and concepts at time of answer
qst_reference:      list of subjects and concepts that were classified for the answered question-answer pair

| time_stamp | qst_ans_reference | qst_reference | participant_id | response_time | response_result | first_attempt_tf |
| ---------- | ----------------- | ------------- | -------------- | ------------- | --------------- | ---------------- |
| date_time  | String            | json_object   | uuid           | time_seconds  | 1, 0.5, 0.25, 0 | bool             |

# Other Considerations for data to incorporate for analysis
The concerns with this project quickly meander into problems with privacy and data security. So much of the data we could collect may or may not be ethical to acquire. For this reason, the base approach I am taking is to prompt users to sync data from platforms that have already collected their data. Then using that personal data, we can match it up against the time_stamps recorded when questions were answered. The result should be a very detailed record of the state of the user at that moment in time. Which allows us to have comprehensive data for training a neural network to predict when the user is most likely to begin forgetting the information presented to them.

My general philosophy is to collect as much data for analysis as possible, as ethically as possible. For many data points I would hypothesis they would have little to no effect on the prediction. Such as location data, which doesn't make logical sense to have an impact on memory retention.
## Sync health data with Quizzer
- Health data recorded from other applications like Samsung Health could be entered into Quizzer to provide additional possible variables that might be at play in predicting memory retention. This would include sleep data, step counts, activity levels, heart rate, blood pressure, diet, and other health metrics. Since the brain is biological it by extension is effected by your overall health.

## Interest Inventory and Psychological Profile Tests
While Psychology test can be seen as gimmicks, it might still be valuable information for analysis, understanding how a user's perceived psychological profile effects their learning abilities.
Examples of pre-existing profiles:
- Myers Brigg
- Autism Assessments
- STRONG inventory

## Location data
- My hypothesis is that locational data has little to no correlation with user performance, collecting this data for analysis should either confirm or deny this assertion. If my hypothesis is correct then locational data collection would be removed from the platform otherwise it would be retained. There are arguments for or against this hypothesis. For example it shouldn't matter which rural town in America you live, but if you reside in an area that is oppressive, conducts human rights violations, or other such tactics, this would very much effect memory retention. However it's unlikely that victims in those areas would be using this software to begin with.
