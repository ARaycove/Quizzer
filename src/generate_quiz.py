from lib import helper
import system_data
from datetime import datetime, timedelta
import system_data_user_stats
import system_data_question_stats
import random
###############################################################
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
            question_stat_block = user_profile_data["questions"]["reserve_bank"][question_id]
            if question_stat_block.get("average_times_shown_per_day") == None:
                question_stat_block = system_data_question_stats.calculate_average_shown(question_stat_block)
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

def remove_questions_from_circulation(average_daily_questions, desired_daily_questions, user_profile_data: dict) -> dict: #Private Function
    print("Removal of questions disabled, while system re-evaluates new formula")    
    return user_profile_data
    target = average_daily_questions - (desired_daily_questions * 1.05) # if 100 is desired and 111 exist then 5% above threshold is the target, the count variable would then be 111-105 = 6.                                                               
    questions_to_remove_from_in_circulation_is_eligible = []
    questions_to_remove_from_in_circulation_not_eligible = []
    total_in_bank = 0
    total_removed = 0
    # We would then subtract from 6 until target <= 0
    
    for pile_name, pile in user_profile_data["questions"].items():
        total_in_bank += len(pile)
    print(f"    Currently have {total_in_bank} total questions")

    for pile_name, pile in user_profile_data["questions"].items():
        if target <= 0:
            break #if the target is met break out of this loop as well
        if pile_name != "in_circulation_not_eligible" or pile_name != "in_circulation_is_eligible":
            continue
        # Should iterate and remove from the circulating non-eligible pile first
        print(f"    Iterating over questions in <{pile_name}>")
        for unique_id, question_object in pile.items():
            if question_object["in_circulation"] == True:
                question_object["in_circulation"] = False
                write_data = {unique_id: question_object}
                # Now that the question is not in circulation move it to the reserve bank and mark it for deletion from this pile
                user_profile_data["reserve_bank"].update(write_data)
                #     Depends on where the question came from
                if pile_name == "in_circulation_not_eligible":
                    questions_to_remove_from_in_circulation_not_eligible.append(unique_id)
                elif pile_name == "in_circulation_is_eligible":
                    questions_to_remove_from_in_circulation_is_eligible.append(unique_id)
                
                target -= question_object["average_times_shown_per_day"]
            if target <= 0:
                break #Once target is met break out of this loop
    if target <= 0:
        # remove questions from in_circulation piles:
        for unique_id in questions_to_remove_from_in_circulation_not_eligible:
            del user_profile_data["questions"]["in_circulation_not_eligible"][unique_id]
            total_removed += 1
        for unique_id in questions_to_remove_from_in_circulation_is_eligible:
            del user_profile_data["questions"]["in_circulation_is_eligible"][unique_id]
            total_removed += 1
        # Get total sum again
        second_sum = 0
        for pile_name, pile in user_profile_data["questions"].items():
            second_sum += len(pile)
        print(f"    Now have {second_sum} in question piles")
        # If the sums are not the same then we've deleted a question, should throw an exception to avoid deleting, then debug the issue
        if total_in_bank != second_sum:
            raise Exception("Old total doesn't match new total, some questions were deleted")
        print(f"    Removed {total_removed} questions from circulation")
        return user_profile_data
    else:
        print("    ALERT!! Exhausted all questions, but target was not met")
        return user_profile_data
        
def update_questions_in_circulation(user_profile_data: dict, question_object_data: dict) -> dict: #Private Function
    '''
    Determines whether questions should be pulled from circulation or added into circulation, based on the desired daily questions settings and the current average daily shown stat
    after determination is made, function calls either remove_questions_from_circulation() or add_questions_into_circulation
    '''
    # print("def quiz_functions.update_questions_in_circulation(user_profile_data: dict) -> dict")
    # Load in user data
    settings_data = user_profile_data["settings"]
    stats_data = user_profile_data["stats"]
    
    # assign variables with user data we are working with.
    average_daily_questions = stats_data["average_questions_per_day"]
    desired_daily_questions = settings_data["desired_daily_questions"]
    # print(f"    Current average daily questions being shown is: {average_daily_questions}")
    # print(f"    Current desired daily questions to be shown is: {desired_daily_questions}")
    if average_daily_questions >= desired_daily_questions * 1.10: # 10% threshold, so if desired is 100, if we exceed 110 the script will reduce the amount of questions in circulation
        # print("    Too many in circulation, removing questions. . .")
        user_profile_data = remove_questions_from_circulation(average_daily_questions, desired_daily_questions, user_profile_data) # For ease of reading, seperate the removal process into its own function
        # print("    Finished updating list of circulating questions")
        user_profile_data = system_data.update_stats(user_profile_data, question_object_data)
        return user_profile_data
    elif average_daily_questions < desired_daily_questions: # Indicating we need to add questions
        # print("    Not enough questions in circulation, adding questions. . .")
        user_profile_data = add_questions_into_circulation(average_daily_questions, desired_daily_questions, user_profile_data, question_object_data)
        # print("    Finished updating list of circulating questions")
        user_profile_data = system_data.update_stats(user_profile_data, question_object_data)
        return user_profile_data
    else:
        # print("    No need to add or remove questions right now")
        # print("    Finished updating list of circulating questions")
        user_profile_data = system_data.update_stats(user_profile_data, question_object_data)
        return user_profile_data


def populate_question_list(user_profile_data: dict, question_object_data: dict) -> list:
    # New system simply grabs x amount of questions that are eligible
    # If no eligible questions returns an empty list
    # FIXME Deprecated!
    print("def public_functions.populate_question_list(user_profile_data: dict, question_object_data: dict) -> list")
    print("    Calling settings.build_subject_settings()")
    user_profile_data["settings"]["subject_settings"] = system_data.build_subject_settings(user_profile_data, question_object_data)
    print("    Calling quiz_functions.update_questions_in_circulation(user_profile_data)")
    
    user_profile_data = update_questions_in_circulation(user_profile_data, question_object_data) # Start by ensuring questions are put into circulation if we can fit them in the average
    ##################################################
    # filter out questions based on criteria
    question_list = [unique_id for unique_id in user_profile_data["questions"]["in_circulation_is_eligible"].keys()]
    
    random.shuffle(question_list) # ensures there is some level of randomization, so users don't notice this is just a cycling list
    question_list = question_list[::-1] # Reverse the list
    random.shuffle(question_list) # Shuffle it again
    print(f"    List of {len(question_list)} questions has been shuffled for pseudorandomness.")
    print(f"    {question_list}")
    return (question_list, user_profile_data)