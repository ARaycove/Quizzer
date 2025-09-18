Every good scientific inquiry starts with a line of questions to guide that research.


# Given any piece of information, or any question, what is the probability you will answer that question correctly if asked right now?
**Short Answer**: probability, we capture real user interaction data with questions using an existing formula, recording the results. We then take that set of data and run a linear regression model to fit the data, and that will spit out the formula for what the probability of correctness is based on our parameters.

# What parameters will be required to calculate the probability of correctness, most accurately
See [[Neural-Net Layer]] Diagram for outline of the input layer to our probability model

**Sleep meta-data**: Current research highly suggests that sleep quality and duration are highly correlated to cognitive performance for this reason we will include some basic meta-data for sleep metrics. Set of sleep data can be gotten by physical devices, to collect this and have it be good for the model, we need users who willingly sync their health data with us, which is recorded by other applications.

---
**Health Metrics**: The list of health metrics, given a user syncs their health data with us for analysis
n features
**User Specific Metrics**
6 features

| Feature                    | description                                                                                                        | purpose                                                                                            |
| -------------------------- | ------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------- |
| overall_average_hesitation | Across all questions, what is the average amount of time it takes for the given user to begin answering a question | place hesitation time in context with overall performance                                          |
| overall_reaction_time      | Across all questions, on average, how long does it take to go from presentation to answer submisssion              | meta-data                                                                                          |
| revision_streak_sum        | vector containing questions counts in profile by revision score                                                    | Engineered feature, to provide additional information regarding cumulative performance of the user |
| total_questions_in_profile | the total number of questions that have been introduced to the user                                                | cumulative performance metric                                                                      |
| average_daily_learned      | currently learning rate, measured by how many new questions are introduced to the user on a daily basis            | cumulative performance metric                                                                      |
| average_daily_answered     | the amount of questions the user answers per day on average                                                        | cumulative performance metric                                                                      |


**Question Performance Data**
23 features

| Feature                     | description                                                                                                                                                                 | purpose                                                                                                                                                                                             |
| --------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| transformed_question_vector | The text and media content of the question ran through a transformer returning the numerical vector representation of the question record                                   | Tells the model the content of the question that is being assessed for probability of correctness                                                                                                   |
| module_name                 | Which module is this question a part of                                                                                                                                     | one hot encoded vector. Will update this as models are trained and retrained                                                                                                                        |
| question_type               | What is the question_type being answered                                                                                                                                    | Does the type of the question have an effect on ability to recall? Are MCQ's more retainable than fill in the blank?                                                                                |
| number_mcq_options          | The total number of multiple choice options                                                                                                                                 | Does the number of multiple choice options effect the prediction                                                                                                                                    |
| number_sort_order_options   | The total number of elements in the sort order question that the user needs to sort                                                                                         |                                                                                                                                                                                                     |
| number_select_all_options   | type dependent, number of options for select all that apply                                                                                                                 |                                                                                                                                                                                                     |
| number_blank_options        | type dependent, how many blanks are there                                                                                                                                   |                                                                                                                                                                                                     |
| avg_length_of_blanks        | On average how long is the answer string                                                                                                                                    |                                                                                                                                                                                                     |
| is_math_blank               | If fill in the blank is this a math input?                                                                                                                                  | Do mathematics based questions have an impact on retention?                                                                                                                                         |
| first_attempt               | Is this the first time the user has been presented with this question?                                                                                                      | historical performance data, indicates there is no performance data on this specific question                                                                                                       |
| total_attempts              | At time of presentation, how many times has the user attempted this exact question in the past.<br>This is big N and can be used to recalculate means with a bit of algebra | historical performance data used to predict future performance                                                                                                                                      |
| total_correct_attempts      | the total number of correct responses                                                                                                                                       |                                                                                                                                                                                                     |
| total_incorrect_attempts    | the total number of incorrect responses                                                                                                                                     |                                                                                                                                                                                                     |
| question accuracy rate      | total_correct_attempts/total_attempts                                                                                                                                       |                                                                                                                                                                                                     |
| question inaccuracy rate    | total_incorrect_attempts/total_attempts                                                                                                                                     |                                                                                                                                                                                                     |
| revision_streak             | calculated by adding one if user answered it correctly, and subtracting one if the user answers incorrectly. The revision_streak at time of presentation                    | The higher this score is, the more accurate they've been. Take in conjunction with total-attempts to get a more complete picture of overall accuracy.                                               |
| last_revised_UTC            | At time of presentation when was the last time they answered this? When predictions are being made, calculate this at time of prediction                                    | UTC time ensures that this is a consistent time metric across the entire attempt data across all users. To be different than local time, which is meant to track sleep metrics                      |
| days_since_last_revision    | taking last_revised_UTC, what is the floating point value in days since the user last answered the question at time of presentation                                         | historical performance data, a time metric to help established patterns of time with memory decay                                                                                                   |
| current_time_UTC            | What is the current time of presentation? To be calculated at time when entered into the prediction algorithm                                                               | UTC time now when the calculation is ran. This metric will always be fed in as current time now in live operation, for training this will be the time_stamp recorded on the question attempt record |
| days_since_first introduced | using the timestamp field, calculate how many days it's been since the user first saw this question                                                                         |                                                                                                                                                                                                     |
| attempt_day_ratio           | total_attempts / days_since_first_introduced                                                                                                                                |                                                                                                                                                                                                     |
| average_hesitation          | In days (normalized) how long did it take them from time of presentation, to click on the answer field?                                                                     | Initial reaction time, hopefully this is a measure of engagement, disengaged users would take longer.                                                                                               |
| average_reaction_time       | At time of attempt reaction time is recorded, give the average amount of time the user takes to answer the specific question                                                | From time of presentation to hitting submit, time in days. Measure of speed with this question                                                                                                      |
**Module Performance Data**
To be meaningful to the model, all module vectors will be ordered alphabetically by name, to ensure that all module vectors combined result in uniform ordering.

We will label every such feature set as ```{module_name}_feature_name```

Does the number of questions by type effect accuracy?
Do individual question types effect accuracy?
Does partial versus full exposure to a module introduce transfer learning benefits?

| feature          | description                                                                                                                                  | purpose |
| ---------------- | -------------------------------------------------------------------------------------------------------------------------------------------- | ------- |
| num_mcq          | the number of mcq's in this module                                                                                                           |         |
| num_fitb         | the number of fill in the blank questions                                                                                                    |         |
| num_sata         | the number of select all that apply questions                                                                                                |         |
| num_tf           | the number of true_false questions                                                                                                           |         |
| num_so           | the number of sort order questions                                                                                                           |         |
| num_total        | total number of questions in this module                                                                                                     |         |
| total_seen       | the total number of questions in this module that are in the user's profile, that have been answered at least once revision_streak is $>= 1$ |         |
| percentile_seen  | In this module, what is the total_seen / num_total ratio                                                                                     |         |
| total_attempts   | How many questions have been attempted in this specific module                                                                               |         |
| total_correct    | total correct attempts                                                                                                                       |         |
| total_incorrect  | total incorrect attempts                                                                                                                     |         |
| overall_accuracy | the number of correct attempt versus incorrect attempts inside this module                                                                   |         |
## Some other Questions
Does the amount of time a user is awake for, effect their accuracy?


# Given a large dataset of questions and their answers, how do we efficiently group them and link them together in order to capture, numerically, the relationship between them

