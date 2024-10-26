from lib import helper
import system_data
from datetime import datetime, timedelta
import system_data_user_stats
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
            ratio_for_tier = 0
    print(f"    Tier number: < {tier_number} > ratios are:")
    for key, value in ratio_for_tier.items():
        print(f"    {key:^25}:{value}")
    return ratio_for_tier
###############################################################
def add_questions_into_circulation(average_daily_questions: float, desired_daily_questions: int, user_profile_data: dict, question_object_data: dict) -> dict: #Private Function
    print("def add_questions_into_circulation(average_daily_questions: float, desired_daily_questions: int, user_profile_data: dict, question_object_data: dict) -> dict:")
    # Logic, check for each subject, the total amount of questions existing and the total amount in circulation, if these numbers are equal for every subject then we terminate this function since there is nothing to add
    settings_data = user_profile_data["settings"]
    length_to_check = len(settings_data["subject_settings"].keys())
    for subject in settings_data["subject_settings"]:
        num_in_circ = settings_data["subject_settings"][subject]["num_questions_in_circulation"]
        total_activated_qs = settings_data["subject_settings"][subject]["total_activated_questions"]
        # Tally up how many questions that are currently activated by a module
        
        if settings_data["subject_settings"][subject]["has_available_questions"] == False:
            print(f"    ALERT!!! Subject: {subject} has no remaining questions to add, consider getting more questions related to this subject")
        else:
            print(f"    Subject <{subject:^25}> has < {total_activated_qs-num_in_circ} > remaining questions in reserve")    
    
    ##########################################################################################
    print("    Adding questions into circulation")
    stats_data = user_profile_data["stats"]
    questions_data = user_profile_data["questions"]
    # First we need to get a list of all subject matters sorted by priority
    print("    Subject List:")
    subject_list = [i for i in settings_data["subject_settings"].keys()]
    original_list = sorted(subject_list, key=lambda x: settings_data['subject_settings'][x]['priority'])
    sorted_subject_list = original_list # Create a copy and an original
    for sub in sorted_subject_list:
        print(f"        {sub}")
    # Second we need to determine the target number of questions to enter, this target is modified by a float value representing the average times per day a question is shown. 
    # Each question has a value less than 1
    # So essentially a target of 10 does not mean we add in only ten questions, but however many we need to get the average figure to the desired figure
    target = desired_daily_questions - average_daily_questions # so if desired is 100, and average is 90, target is 10. We subtract from the target until we reach 0
    tier_number = 1
    target_met = False
    
    # "us_military": {"interest_level": 100, "priority": 1, "total_questions": 66, "num_questions_in_circulation": 66}
    timer = 2 #NOTE Purpose of timer is a bit redundant now, loop has safeguards to prevent infinite loops, but for now we'll keep the timer until such time where it's safe to remove this failsafe, or this message can be removed if we decide that the failsafe is better left in. (I'm leaning towards this conclusion)
    time_start = datetime.now()
    subjects_to_skip = []
    questions_to_remove_from_reserve_bank = []

    print("    Entering addition loop")
    # After this point we should only deal in user_profile_data object so we can update it directly
    while True:
        total_questions_in_reserve_bank = len(user_profile_data["questions"]["reserve_bank"])
        print(f"    There are {total_questions_in_reserve_bank} total questions in the reserve_bank pile")
        ratio_for_tier = calculate_ratio_for_tier(tier_number, sorted_subject_list, user_profile_data)
         # will be False
        # Determine what subjects should be skipped for this iteration
        subjects_to_skip = determine_questions_to_skip(tier_number, ratio_for_tier, user_profile_data)
        # Now Mutate the ratio_for_tier variable so each key value pair reads {subject: num_questions_to_add}
        # 1st set any subjects we are skipping to a goal of 0
        for subject in subjects_to_skip:
            ratio_for_tier[subject] = 0
        # determine if all subjects are 0
        all_zero = helper.all_zero(ratio_for_tier)
        # 2nd subtract the current circulating questions from the value of each subject
        for subject, value in ratio_for_tier.items():
            num_in_circ = user_profile_data["settings"]["subject_settings"][subject]["num_questions_in_circulation"]
            value -= num_in_circ # if the target for the tier is 10 and the number in circulation is 8 then the new value becomes 2, representing the number of questions left to choose to meet the target for that tier
            print(f"    Subject: <{subject:^25}> Needs < {value} >  questions to meet target")
        # Now that we have a dictionary representing the total amount of questions to add for each subject for current tier, we need to iterate over the reserve_bank of questions:
        # OMG A TRIPLE NESTED FOR LOOP!!!!!
        # Access the reserve_bank of questions only -> these questions should be marked not in circulation
        for pile_name, pile in user_profile_data["questions"].items():
            if target_met == True:
                print("    Target Met: breaking from loop <for pile_name, pile in user_profile_data['questions'].items()>")
                break
            if all_zero == True:
                print("    Tier Values met: breaking from loop <for pile_name, pile in user_profile_data['questions'].items()>")
                break
            if pile_name != "reserve_bank":
                continue
            # Add <value> questions for each subject
            for subject, value in ratio_for_tier.items():
                if target_met == True:
                    print("    Target Met: breaking from loop <for subject, value in ratio_for_tier.items()>")
                    break
                if all_zero == True:
                    print("    Tier Values met: breaking from loop <for pile_name, pile in user_profile_data['questions'].items()>")
                    break
                for unique_id, question_object in pile.items():
                    if subject in question_object_data[unique_id]["subject"]:
                        # If we find a qualifying question:
                        # Switch the question to True
                        question_object["in_circulation"] = True
                        # update the question's properties
                        question_object = system_data.update_user_question_stats(question_object, unique_id, user_profile_data, question_object_data)
                        # Add the question to either "in_circulation_not_eligible" or "in_circulation_is_eligible" pile
                        write_data = {unique_id: question_object}
                        if question_object["in_circulation"] == True:
                            # Manually increment and decrement values in subject_settings so we don't need to rebuild the whole data structure
                            user_profile_data["settings"]["subject_settings"][subject]["num_questions_in_circulation"] += 1
                        if question_object["in_circulation"] == True and question_object["is_eligible"] == True:
                            questions_to_remove_from_reserve_bank.append(unique_id)
                            total_questions_in_reserve_bank -= 1
                            user_profile_data["questions"]["in_circulation_is_eligible"].update(write_data)
                            print(f"    Added question with id <{unique_id}> to in_circulation_is_eligible pile")
                        if question_object["in_circulation"] == True and question_object["is_eligible"] == False:
                            questions_to_remove_from_reserve_bank.append(unique_id)
                            total_questions_in_reserve_bank -= 1
                            user_profile_data["questions"]["in_circulation_not_eligible"].update(write_data)
                            print(f"    Added question with id <{unique_id}> to in_circulation_not_eligible pile")
                        ratio_for_tier[subject] -= 1 # This is the value
                        target -= question_object["average_times_shown_per_day"]
                        # Conditions for breaking the loop
                        if target <= 0:
                            print(f"    Target met! Leaving the loop (target hit 0 -> {target})")
                            target_met = True
                            break
                        if total_questions_in_reserve_bank <= 0:
                            print("    Target met! Leaving the loop (no questions left in reserve bank)")
                            target_met = True
                            break
                        if helper.all_zero(ratio_for_tier.values) == True:
                            all_zero = True
                            break
        print(f"    Removing {len(questions_to_remove_from_reserve_bank)} from reserve_bank")
        for unique_id in questions_to_remove_from_reserve_bank:
            del user_profile_data["questions"]["reserve_bank"][unique_id]
            # Question pile is now accurate
            


        if all_zero == True: # Meaning the target has not been met and we've met the ratio for the current tier
            # Increment the tier number, we then go back to the header while loop and recalculate
            tier_number += 1
        # Conditions Required to exit the loop
        elapsed_time = datetime.now() - time_start
        # If there are no questions in the reserve bank:
        if len(user_profile_data["questions"]["reserve_bank"]) == 0:
            print("    No remaining questions in the reserve bank")
            return user_profile_data
        # If we've met the target to put in
        elif target_met == True:
            return user_profile_data    
        # If the process takes too long
        elif elapsed_time >= timedelta(seconds=timer):
            print("Times Up, Sorry took too long")
            return user_profile_data

def remove_questions_from_circulation(average_daily_questions, desired_daily_questions, user_profile_data: dict) -> dict: #Private Function
    print("def quiz_functions.remove_questions_from_circulation(average_daily_questions, desired_daily_questions, user_profile_data: dict) ->")
    
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
    print("def quiz_functions.update_questions_in_circulation(user_profile_data: dict) -> dict")
    # Load in user data
    settings_data = user_profile_data["settings"]
    stats_data = user_profile_data["stats"]
    
    # assign variables with user data we are working with.
    average_daily_questions = stats_data["average_questions_per_day"]
    desired_daily_questions = settings_data["desired_daily_questions"]
    print(f"    Current average daily questions being shown is: {average_daily_questions}")
    print(f"    Current desired daily questions to be shown is: {desired_daily_questions}")
    if average_daily_questions >= desired_daily_questions * 1.10: # 10% threshold, so if desired is 100, if we exceed 110 the script will reduce the amount of questions in circulation
        print("    Too many in circulation, removing questions. . .")
        user_profile_data = remove_questions_from_circulation(average_daily_questions, desired_daily_questions, user_profile_data) # For ease of reading, seperate the removal process into its own function
        print("    Finished updating list of circulating questions")
        return user_profile_data
    elif average_daily_questions < desired_daily_questions: # Indicating we need to add questions
        print("    Not enough questions in circulation, adding questions. . .")
        user_profile_data = add_questions_into_circulation(average_daily_questions, desired_daily_questions, user_profile_data, question_object_data)
        print("    Finished updating list of circulating questions")
        return user_profile_data
    else:
        print("    No need to add or remove questions right now")
        print("    Finished updating list of circulating questions")
        return user_profile_data


def populate_question_list(user_profile_data: dict, question_object_data: dict) -> list:
    # New system simply grabs x amount of questions that are eligible
    # If no eligible questions returns an empty list
    print("def public_functions.populate_question_list(user_profile_data: dict, question_object_data: dict) -> list")
    print("    Calling settings.build_subject_settings()")
    user_profile_data["settings"]["subject_settings"] = system_data.build_subject_settings(user_profile_data, question_object_data)
    print("    Calling quiz_functions.update_questions_in_circulation(user_profile_data)")
    
    user_profile_data = update_questions_in_circulation(user_profile_data, question_object_data) # Start by ensuring questions are put into circulation if we can fit them in the average
    user_profile_data = system_data.update_stats(user_profile_data, question_object_data)
    
    ##################################################
    # filter out questions based on criteria
    question_list = [unique_id for unique_id in user_profile_data["questions"]["in_circulation_is_eligible"].keys()]
    
    random.shuffle(question_list) # ensures there is some level of randomization, so users don't notice this is just a cycling list
    question_list = question_list[::-1] # Reverse the list
    random.shuffle(question_list) # Shuffle it again
    print(f"    List of {len(question_list)} questions has been shuffled for pseudorandomness.")
    print(f"    {question_list}")
    return (question_list, user_profile_data)