# Task_02: Generate question-answer pairs and provide classification for those pairs

This block of tasks instructs the participant user to generate questions based on source material provided in [[03_04_Task_01_Source_Material_Generation_and_Classification|Task 01]], generate answers to those questions, classify them based on subject matter and conceptual matter, and review each to ensure the question-answer pair is properly derived from the source material.

![[Pasted image 20250407093838.png]]

## Task_02a: Generate questions based on source material
As the first task progresses, participants will be tasked with reading the individual passages recorded. Only the source material will be shown without reference to the academic citation itself. The purpose of the citation is so Quizzer can properly give credit and/or verify individual sources if news breaks that certain studies or sources have been discredited.

There is potential for multiple questions or phrasings of questions to occur, so the result of the entry for this task will be a list of possible questions, which may or may not include image data, audio, or video. The resulting data structure from this task will be an array, where each item in the array is an array of length 4 [question_text, question_image, question_audio, question_video]. The first item will be a string, the rest can be stored as BLOB in the SQL database. If image, audio, or video are not included, a NULL value will be put in that position in the array as a placeholder. Once the task is submitted, the list of questions generated will be entered as records for every item in the list. 

**Guidelines for generating good questions:**

- Questions should be self-contained with adequate context divorced from the original passage
- Questions should avoid vague references (e.g., "according to the document," "the study shows," etc.)
- If a question relies on knowledge of a specific thing, that specific thing should be mentioned in the context
- For history-related topics, include dates wherever possible
- Always use full names when referencing people
- Avoid vague temporal references when referring to time periods or dates
- Use numbers instead of words when citing century (e.g., "19th c." as opposed to "nineteenth century")

An example of a passage where multiple questions can be derived is a history book that mentions a specific person, (birth-death year) and a simple description of what they did. In this one sentence we can extract the name of the person against what they did: When were they born? When did they die? What are the birth and death years of that person? What did so and so do? What are so and so known for? All of these are possible and acceptable outputs.

Since not every participant will derive an exhaustive list of questions for a given passage, this subset of Task_02 should be repeated several times to ensure a sufficient variety of questions.

**Note: A complete worked example should be added here showing a sample passage, multiple questions generated from it, corresponding answers, and how they would be classified.**

## Task_02b: Generate Answers to questions based on the source material
After questions have been generated in Task_02a, participants will engage in the answer generation task. The user interface will present participants with:
1. The original source passage
2. A single question derived from that passage
3. Input fields for the answer components: [answer_text, answer_image, answer_audio, answer_video]

A tool will be provided to screenshot or access an media data in the provided passage so that they can be copied into the answer fields.

Participants will read both the passage and the question carefully, then formulate an appropriate answer based solely on the information contained in the passage. The primary response should be entered in the answer_text field, with supplementary media (images, audio, or video) added only when necessary to properly convey the answer.

When generating answers, participants should adhere to these guidelines:
- Provide direct quotes from the source material wherever possible to support the answer
- Ensure the answer directly addresses the specific question asked without extraneous information
- Keep answers concise and focused on the information requested
- Use clear, precise language that accurately reflects the content of the passage
- If the passage doesn't contain sufficient information to answer the question completely, the question should be flagged
- For factual questions, prioritize accuracy over elaboration
- For conceptual questions, ensure explanations remain faithful to the passage's intent

The quality of these answers will directly impact the effectiveness of the Quizzer system as a learning tool, making this task a critical component in the knowledge acquisition pipeline.
## Task_02c: Subject and Concept Classification Task
This task is relatively straightforward. A user will be presented with a question-answer pair along with either a subject or concept. At the beginning of the session, the user will be told whether they will classify subjects or concepts for question-answer pairs. Subjects will be selected at random from a list of 2080 academic field names located in the subject_data/subject_taxonomy.py file. Concepts selected to be compared will be derived from the Key Term identification Task.

This task will be self-paced and proceed as follows:

1. The participant will be presented with a question-answer pair, displayed at the same time. Alongside this will be a standard question: Does the question-answer pair above relate to the <"subject" or "concept"> (whichever they are currently classifying against) <name_of_subject_or_concept>?
2. Once the prompt is given, the user will be presented with a scale, asking the user to rate how much the concept or subject matter relates, given a 0-10 scale, which will be converted to a 0-1 value for algorithmic processing. This will provide a gauge of confidence alongside the accuracy response.

Concepts and Subjects will be derived from these results by summing up the weights of the results. A value > 0.5 will allow that subject to be placed into the list. If further classification results cause this value to drop to val <= 0.50, then it will be removed from the list dynamically.

## Task_02d: Validation and Manual Review
This task involves reading and understanding the prompted question-answer pair, then reading the source material that is claimed in its entry.

"Properly derived" means that:
- The answer can be clearly understood from the passage
- The answer logically follows the question
- The question can be answered from the given passage

For example, if the passage is about HTML structure with no mention of JavaScript, the question can't reasonably be in regards to JavaScript.

If the reviewer deems that the question-answer pair is not properly derived from the source material, the question-answer pair will be flagged for removal or modification. If the reviewer deems that they can modify the question-answer pair so it does properly derive from the source material, they shall do so. Otherwise, if the question-answer pair is non-sensical and can't reasonably be modified, it shall be flagged for removal. The user uuid of the reviewer will be recorded.

To ensure quality control over time, content should undergo annual reviews where different reviewers assess the content, ensuring fresh perspectives on the material. Additionally, the review task could be simplified to asking "Can this question be answered using this document alone?" while providing both the question and passage.


**Data Structure for these are described in these sections:**
[[08_08_Question_Answer_Pair_Table]]
[[08_10_Subject_Concept_Classification_Results]]