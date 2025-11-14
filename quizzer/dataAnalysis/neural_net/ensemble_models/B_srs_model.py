# sub-model
# Focus is on learning the relationship of immediate performance with projected accuracy
# The target is "response_result"
'''
The immediate features this model will learn are:
num_blanks,
num_mcq_options,
num_sata_options,
num_so_options,
revision_streak,
total_attempts,
total_correct_attempts,
total_incorrect_attempts,
was_first_attempt,
accuracy_rate,
attempt_day_ratio,
avg_react_time,
days_since_first_introduced,
days_since_last_revision,
question_type_fill_in_the_blank,
question_type_multiple_choice,
question_type_select_all_that_apply,
question_type_sort_order,
question_type_true_false
qv_*
'''
# We will train multiple small models where each small model takes the entirety of the question performance information, and a random selection of
# the question vector, equal to the total of performance parameters. So if there are 300 qv elements and the length of performance metricsis 30,
# then we will train 10 models, where each model learns the SRS pattern alongside a portion of the semantic information.
# Using this pattern, the semantic content of the question vector will make it into the final model, without the question vector overshadowing everything
# else 
