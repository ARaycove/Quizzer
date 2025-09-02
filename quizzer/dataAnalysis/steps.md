1. Run sync_fetch_data.py to update the working database from what's on server
2. run transform_question_to_vector to run the vectorization of the data and save it locally
3. Now you can run the individual data analysis files
    - 


- vectorized_data.parquet is:
The data structure is a Pandas DataFrame that represents vectorized question and answer pairs.

Each row in the DataFrame corresponds to a single question-answer entry. The columns contain numerical vector representations of the original data.
- Question Text: A column containing a numerical vector (a list or NumPy array of floating-point numbers) that represents the vectorized text of the question.
- Answer Text: A column containing a numerical vector representing the vectorized text of the answer.
- Question Media: A column containing a numerical vector representing the vectorized media (e.g., images) associated with the question. This vector will be all zeros if no media is present.
- Answer Media: A column containing a numerical vector representing the vectorized media associated with the answer. This vector will also be all zeros if no media is present.

The purpose of this DataFrame is to store a combined numerical representation of both text and media content, which can then be used for tasks like similarity search or clustering.




{0: 
    {
    'question_id': '2025-05-04T12:44:56.594619_7465dce6-abcf-4963-92a1-30dd7118c23a', 
    'time_stamp': '2025-05-04T12:44:56.594619',
    'citation': None,
    'question_elements': [{'type': 'text', 'content': 'Select all the ODD numbers.'}],
    'answer_elements': [{'type': 'text', 'content': 'Odd numbers are not divisible by 2.'}], 
    'concepts': None, 
    'subjects': None, 
    'module_name': 'is even or odd', 
    'question_type': 'select_all_that_apply', 
    'options': [{'type': 'text', 'content': '17'}, {'type': 'text', 'content': '50'}, {'type': 'text', 'content': '23'}, {'type': 'text', 'content': '41'}, {'type': 'text', 'content': '49'}, {'type': 'text', 'content': '7'}], 
    'correct_option_index': None, 'correct_order': None, 
    'index_options_that_apply': '[0,2,3,4,5]', 
    'qst_contrib': '7465dce6-abcf-4963-92a1-30dd7118c23a', 
    'ans_contrib': '', 
    'qst_reviewer': '', 
    'has_been_reviewed': 0, 
    'ans_flagged': 0, 
    'flag_for_removal': 0, 
    'completed': 1,
    'last_modified_timestamp': '2025-05-07T15:53:16.433060Z', 
    'has_media': None, 
    'answers_to_blanks': None
    }
}