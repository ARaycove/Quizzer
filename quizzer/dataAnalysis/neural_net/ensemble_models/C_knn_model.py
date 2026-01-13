# sub-model
# This model learns how a related question effects prediction of the target
# For each training sample we can separate out 25 samples to train this one
# The target is "response_result"

'''
Features in this model are:
knn_01_num_blanks,
knn_01_num_mcq_options,
knn_01_num_sata_options,
knn_01_num_so_options,
knn_01_revision_streak,
knn_01_total_attempts,
knn_01_total_correct_attempts,
knn_01_total_incorrect_attempts,
knn_01_was_first_attempt,
knn_01_accuracy_rate,
knn_01_attempt_day_ratio,
knn_01_avg_react_time,
knn_01_days_since_first_introduced,
knn_01_days_since_last_revision,
knn_01_distance,
knn_01_question_type_fill_in_the_blank,
knn_01_question_type_missing,
knn_01_question_type_multiple_choice,
knn_01_question_type_select_all_that_apply,
knn_01_question_type_sort_order,
knn_01_question_type_true_false,

'''