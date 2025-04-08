The current iteration of the Question_Circulation_Selection Algorithm involves gathering all questions that are not currently in circulation under the user_profile. We then get the user interest settings, and treat the value of the interest for a given subject as a ratio. At a high level, the goal is to maintain a ratio of questions according to their subject value.

%% We need to strip this script down and place into a properly formatted description so that it can be more easily replicated. The description of the algorithm is best formatted as a linear numbered list. Algorithm does x, then y, then z. Currently the algorithm calculates how many questions should be added based on the current average daily shown figure. However the algorithm should be updated to take a default argument int 1, where the argument tells the argument how many questions to add before returning %%
The old script for this algorithm is recorded as follows:
```python
def determine_questions_to_skip(tier_number: int, ratio_for_tier: dict, user_profile_data: dict) -> dict:
    print("def determine_questions_to_skip(tier_number, settings_data)")
    subjects_to_skip = []
    # Determine every subject
    for subject in user_profile_data["settings"]["subject_settings"]:
        target_for_tier = ratio_for_tier[subject]
        currently_circulating = user_profile_data["settings"]["subject_settings"][subject]["num_questions_in_circulation"]
        # Skip the subject if no available questions
        if user_profile_data["settings"]["subject_settings"][subject]["has_available_questions"] == False:
            subjects_to_skip.append(subject)
            continue
        # Skip the subject if the target for tier is already met
        if target_for_tier <= currently_circulating:
            subjects_to_skip.append(subject)
            continue
    print(f"    return value subjects_to_skip has type: < {type(subjects_to_skip)} >, should be < {type([])} >")
    print(f"    Skipping these subjects :{subjects_to_skip}")
    return subjects_to_skip

###############################################################
def calculate_ratio_for_tier(tier_number: int, sorted_subject_list: list, user_profile_data) -> dict:
    print("def calculate_ratio_for_tier(tier_number: int, sorted_subject_list: list, user_profile_data)")
    ratio_for_tier = {}
    for subject in sorted_subject_list:
        # Calculate how many we should have in this tier
        ratio_for_tier[subject] = tier_number * int(round((user_profile_data["settings"]["subject_settings"][subject]["interest_level"]/5)))
        # Subtract how many we currently have in circulation
        ratio_for_tier[subject] -= user_profile_data["settings"]["subject_settings"][subject]["num_questions_in_circulation"]
        # Result should be the remaining number of questions to add for that subject (Could result in a negative)
        # If the resulting value is negative, we should set the value to zero, so the all_zero function picks it up
        if ratio_for_tier[subject] < 0:
            ratio_for_tier[subject] = 0
    print(f"    Tier number: < {tier_number} > ratios are:")
    for key, value in ratio_for_tier.items():
        print(f"    {key:^25}:{value}")
    return ratio_for_tier
###############################################################
def configure_initial_tier_value(actual_composition, master_ratio, questions_remaining_by_subject):
    tier_value = 1
    for sub in questions_remaining_by_subject:
        if questions_remaining_by_subject[sub] <= 0:
            print(f"Subject: {sub} has no remaining questions")
            actual_composition[sub] = 9999999
    while True:
        # Scan at this tier level:
        for subject in master_ratio.copy():
            target_ratio = master_ratio[subject] * tier_value
            if actual_composition[subject] < target_ratio:
                print(f"Initial Tier Value is: {tier_value}")
                return tier_value
        # If we don't hit the condition, increment the tier value
        tier_value += 1
        
###############################################################
def should_increment_tier_value(actual_composition, master_ratio, tier_value):
    for subject in master_ratio.copy():
        target_ratio = master_ratio[subject] * tier_value
        if actual_composition[subject] < target_ratio:
            return False
    return True
###############################################################
def add_questions_into_circulation(average_daily_questions: float, desired_daily_questions: int, user_profile_data: dict, question_object_data: dict) -> dict: #Private Function
    # How many questions are we adding?
    target = desired_daily_questions - average_daily_questions
    # Every question has a average_daily value, when we add it we will subtract the target value, if the target falls below zero then we're done

    # What if there aren't enough questions to meet the target?
    amount_reserve_bank = len(user_profile_data["questions"]["reserve_bank"])
    if amount_reserve_bank <= 0:
        return user_profile_data
    #   we'll break the loop if the amount in the reserve bank hits 0

    # I want to maintain a ratio of questions so the composition of the questions reflects the interests of the user!
    # Store this master ratio in a dictionary {math: 1, english: 1, astronomy: 5}
    master_ratio                    = {}
    actual_composition              = {}
    working_ratio_targets           = {}
    questions_remaining_by_subject  = {}
    for subject, subject_values in user_profile_data["settings"]["subject_settings"].items():
        ratio_value = round(subject_values["interest_level"] / 5)# divide the value -> ensures other subjects still get into circulation
        master_ratio.update({subject: ratio_value})
    # We have an object to track what the ratio should be, but how do we track what actually is?
        circulating_questions       = subject_values["num_questions_in_circulation"]
        total_activated_questions   = subject_values["total_activated_questions"]
        # What if there aren't any more questions to add for that subject?
        #   For the sake of the calculation we'll say there are a billion circulating questions, immediately overwriting any counts
        questions_remaining_by_subject.update({subject: (total_activated_questions - circulating_questions)})
        actual_composition.update({subject: circulating_questions})
    working_ratio_targets = master_ratio.copy()

    # Configure initial tier_value
    tier_value = configure_initial_tier_value(actual_composition,master_ratio,questions_remaining_by_subject)
    for sub in questions_remaining_by_subject:
        working_ratio_targets[sub] = master_ratio[sub] * tier_value
        if questions_remaining_by_subject[sub] <= 0:
            actual_composition[sub] = 9999999
    print(tier_value)
    print(working_ratio_targets)
    print(actual_composition)
    print(questions_remaining_by_subject)
    for question_id in helper.shuffle_dictionary_keys(user_profile_data["questions"]["reserve_bank"].copy()):
        # Determine whether or not a subject has remaining questions in it
        #    Set the actual composition value to 10 million to inform the computer that we should ignore this subject going forward
        for sub in questions_remaining_by_subject:
            working_ratio_targets[sub] = master_ratio[sub] * tier_value
            if questions_remaining_by_subject[sub] <= 0:
                actual_composition[sub] = 9999999

        # get the list of subjects the specific question covers
        #   In subject settings, if a question has 5 subjects, that question contributes to incrementing each of those fiver subjects
        subjects_list = question_object_data[question_id]["subject"]
        for subject_value in subjects_list: # We need to evaluate every subject that might exist for that question:
            # Gather the information for that subject
            current_subject_target = working_ratio_targets[subject_value]
            current_amount_circulating = actual_composition[subject_value]
            # load in question_object
            question_stat_block = user_profile_data["questions"]["reserve_bank"][question_id]
            # Ensure average times per day shown stat is accurate
            question_stat_block = system_data_question_stats.calculate_average_shown(question_stat_block)
            # Initialize for easy update
            question_to_move = {question_id: question_stat_block}
            
            if current_amount_circulating < current_subject_target:
                question_stat_block["in_circulation"] = True
                question_to_move = {question_id: question_stat_block}
                user_profile_data["questions"]["in_circulation_is_eligible"].update(question_to_move)
                del user_profile_data["questions"]["reserve_bank"][question_id]
                for sub in subjects_list:
                    actual_composition[sub]             += 1
                    questions_remaining_by_subject[sub] -= 1
                target -= question_stat_block["average_times_shown_per_day"]

                print(f"    The target is now: {target}")
                break # If we decide to add the question to circulation then we need to stop iterating over its subjects

            elif current_amount_circulating >= current_subject_target:
                if should_increment_tier_value(actual_composition, master_ratio,tier_value):
                    tier_value += 1      
                # if we decide it should be added because of the subjeect then we should proceed to the next subject for evaluation 

        if target <= 0:
            return user_profile_data
        elif len(user_profile_data["questions"]["reserve_bank"]) <= 0:
            return user_profile_data
    
    return user_profile_data
```