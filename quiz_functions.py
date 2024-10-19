import json
import random
from lib import helper
from settings_functions import settings
from stats_functions import stats
from question_functions import questions
import public_functions
from datetime import datetime, timedelta
##################################################################
# This file will determine how the quiz object is populated,
# The quiz object consists of question objects
##################################################################
##################################################################
def ensure_quiz_length(sorted_questions, quiz_length): #Private Function
    '''
    function provides that the attempted number of questions to be populated into the quiz is <= the number of questions available for selection:
    '''
    if len(sorted_questions) < quiz_length:
        quiz_length = len(sorted_questions)
    if quiz_length <= 0:
        return None
    return quiz_length



##################################################################
def get_number_of_revision_streak_one_questions(sorted_questions):#Private Function
    num_questions = 0
    for unique_id, question in sorted_questions.items():
        if question["revision_streak"] == 1:
            num_questions += 1
    return num_questions
# selection algorithm



##################################################################
def select_questions_to_be_returned(sorted_questions, quiz_length): #Private Function
## questions filled first, if revision streak is 1, always fill these
    question_list = []
    if len(sorted_questions) == 0:
        return []
    # Very simplified logic, since we already determined proportions and eligiblity all we're going to do is as questions from sorted_questions until we meet the quiz length
    for unique_id, question in sorted_questions.items():
        question_list.append(question)
        if len(question_list) >= quiz_length:
            return question_list
        


###############################################################
def determine_questions_to_skip(tier_number, settings_data):
    subjects_to_skip = []
    for subject in settings_data["subject_settings"]:
        interest_level = settings_data["subject_settings"][subject]["interest_level"]/10
        
        num_questions_of_subject = settings_data["subject_settings"][subject]["total_questions"]
        total_activated_questions = settings_data["subject_settings"][subject]["total_activated_questions"]
        num_questions_of_subject = total_activated_questions # In effect, the total number of questions available is based on the total activated questions not the grand total
        
        num_questions_of_subject_in_circulation = settings_data["subject_settings"][subject]["num_questions_in_circulation"]
        
        available_questions = num_questions_of_subject - num_questions_of_subject_in_circulation
        
        target_for_tier = round((tier_number * interest_level))
        
        num_questions_to_choose = target_for_tier
        if available_questions < num_questions_to_choose:
            num_questions_to_choose = available_questions
        # if every question for that subject is in circulation then we skip over adding questions for that subject
        if num_questions_of_subject <= num_questions_of_subject_in_circulation:
            subjects_to_skip.append(subject)
        # if the subject has met the target for the given tier then we will skip over the question
        elif num_questions_of_subject_in_circulation >= target_for_tier:
            subjects_to_skip.append(subject)
        elif total_activated_questions <= 0:
            subjects_to_skip.append(subject)
        else:
            # Subject has available questions, but has not met the target for that tier
            continue
    return subjects_to_skip



###############################################################
def add_questions_into_circulation(average_daily_questions: float, desired_daily_questions: int, user_profile_data: dict) -> dict: #Private Function
    # Logic, check for each subject, the total amount of questions existing and the total amount in circulation, if these numbers are equal for every subject then we terminate this function since there is nothing to add
    settings_data = user_profile_data["settings"]
    length_to_check = len(settings_data["subject_settings"].keys())
    should_terminate_counter = 0
    total_activated_qs_in_database = 0
    for subject in settings_data["subject_settings"]:
        num_in_circ = settings_data["subject_settings"][subject]["num_questions_in_circulation"]
        total_activated_qs = settings_data["subject_settings"][subject]["total_activated_questions"]
        # Tally up how many questions that are currently activated by a module
        total_activated_qs_in_database += total_activated_qs
        print(f"Subject: {subject:<25}|{num_in_circ}/{total_activated_qs}")
        if num_in_circ == total_activated_qs:
            should_terminate_counter += 1
            print(f"ALERT!!! Subject: {subject} has no remaining questions to add, consider getting more questions related to this subject")
            #FIXME Should be updated into a more formal alert system where the user can examine what subject matters are no longer being "taught" and which one's are close to being "full" (become status of former group status)
    if length_to_check == should_terminate_counter:
        print("No remaining Questions to add")
        return None
    
    
    ##########################################################################################
    print("Adding questions into circulation")
    stats_data = user_profile_data["stats"]
    questions_data = user_profile_data["questions"]
    # First we need to get a list of all subject matters sorted by priority
    subject_list = [i for i in settings_data["subject_settings"].keys()]
    original_list = sorted(subject_list, key=lambda x: settings_data['subject_settings'][x]['priority'])
    sorted_subject_list = original_list # Create a copy and an original
    # Second we need to determine the target number of questions to enter, this target is modified by a float value representing the average times per day a question is shown. 
    # Each question has a value less than 1
    # So essentially a target of 10 does not mean we add in only ten questions, but however many we need to get the average figure to the desired figure
    target = desired_daily_questions - average_daily_questions # so if desired is 100, and average is 90, target is 10. We subtract from the target until we reach 0
    tier_number = 1
    # "us_military": {"interest_level": 100, "priority": 1, "total_questions": 66, "num_questions_in_circulation": 66}
    timer = 10 #NOTE Purpose of timer is a bit redundant now, loop has safeguards to prevent infinite loops, but for now we'll keep the timer until such time where it's safe to remove this failsafe, or this message can be removed if we decide that the failsafe is better left in. (I'm leaning towards this conclusion)
    time_start = datetime.now()
    subjects_to_skip = []



    while True:
        print(f"\nCurrent tier number is {tier_number}")
        # reset the termination count after scan. Otherwise the tier number will increment when it's not supposed to.
        termination_count = 0
        # Determine what subjects should be skipped for this iteration
        subjects_to_skip = determine_questions_to_skip(tier_number, settings_data)
        # Make sure there are actually questions able to be added
        # total activated questions:
        total_questions_in_circulation = max(stats_data["total_in_circulation_questions"].values())
        if total_questions_in_circulation >= total_activated_qs_in_database:
            print("$" * 25)
            print("No questions left in the database to add")
            print("$" * 25)
            return None
        for subject in sorted_subject_list:
            count=0
            if subject in subjects_to_skip:
                termination_count += 1
                if termination_count >= len(sorted_subject_list): # Need to check the counter inside this portion, otherwise infinite loop
                # All subjects have an equal or more than the calculated amount for that tier
                    tier_number += 1
                    termination_count = 0
                    break
                continue
            # Every time we iterate over a subject, we will refresh the data to ensure accuracy (This is the largest time sink in the whole program)
            print(f"Refreshing Data, subject: {subject}")

            user_profile_data["questions"] = questions_data
            user_profile_data["stats"] = stats_data
            user_profile_data["settings"] = settings_data
            user_profile_data = public_functions.update_system_data(user_profile_data) # Update data now also returns the data it updated as well as writes to the json, therefore we do not need to fetch it again
            questions_data = user_profile_data["questions"]
            stats_data = user_profile_data["stats"]
            settings_data = user_profile_data["settings"]
            
            # returned_data["eligibility_index"] = eligiblity_index
            # Variables used for calculations
            skip_subject = False
            interest_level = settings_data["subject_settings"][subject]["interest_level"]/10
            target_for_tier = round((tier_number * interest_level))
            num_questions_of_subject = settings_data["subject_settings"][subject]["total_questions"]
            num_questions_of_subject_in_circulation = settings_data["subject_settings"][subject]["num_questions_in_circulation"]
            num_questions_to_choose = target_for_tier - num_questions_of_subject_in_circulation
            available_questions = num_questions_of_subject - num_questions_of_subject_in_circulation
            
            if available_questions < num_questions_to_choose:
                num_questions_to_choose = available_questions
                print(f"{available_questions} remaining Questions available to add for {subject}")
            elif available_questions >= num_questions_to_choose:
                print(f"Questions available to add for {subject}")
            else:
                print("Something went wrong.")
            # Now iterate over each question in the questions.json
            #####################
            
            for unique_id, question_object in questions_data.items():
                activated = question_object["is_module_active"]
                if activated == False:
                    count+=1
                    continue # Continue statement is working, if the questions module is inactive we skip over it          
                elif (question_object["in_circulation"] == False) and (subject in question_object["subject"]):
                    print(f"Placing {unique_id} into circulation, has subject: {subject}")
                    question_object["in_circulation"] = True
                    print(question_object["in_circulation"])
                    question_object["date_first_put_into_circulation"] = helper.stringify_date(datetime.now())
                    # print(f"decrementing number {num_questions_to_choose}")
                    num_questions_to_choose -= 1
                    # print(f"Number left to choose is now {num_questions_to_choose}")
                    # print(f"Target:{target} reduced by {qa['average_times_shown_per_day']}")
                    target -= question_object["average_times_shown_per_day"]
                    # print(f"Target is now {target}")
                    # After every question is added we need to check our targets
                
                if target <= 0:
                    user_profile_data["questions"] = questions_data
                    user_profile_data["stats"] = stats_data
                    user_profile_data["settings"] = settings_data
                    user_profile_data = public_functions.update_system_data(user_profile_data)
                    print(f"Parent module marked as inactive, skipping question. Occured: {count}")
                    return user_profile_data
                if num_questions_to_choose <= 0:
                    user_profile_data["questions"] = questions_data
                    user_profile_data["stats"] = stats_data
                    user_profile_data["settings"] = settings_data
                    user_profile_data = public_functions.update_system_data(user_profile_data)
                    questions_data = user_profile_data["questions"]
                    stats_data = user_profile_data["stats"]
                    settings_data = user_profile_data["settings"]
                    print(f"Parent module marked as inactive, skipping question. Occured: {count}")
                    break
        
        elapsed_time = datetime.now() - time_start
        if elapsed_time >= timedelta(seconds=timer):
            print("Times Up, Sorry took too long")
            user_profile_data["questions"] = questions_data
            user_profile_data["stats"] = stats_data
            user_profile_data["settings"] = settings_data
            user_profile_data = public_functions.update_system_data(user_profile_data)
            return user_profile_data

def remove_questions_from_circulation(average_daily_questions, desired_daily_questions, user_profile_data: dict) -> dict: #Private Function
    print("Removing questions from circulation")
    target = average_daily_questions - (desired_daily_questions * 1.05) # if 100 is desired and 111 exist then 5% above threshold is the target, the count variable would then be 111-105 = 6.                                                               
    questions_data = user_profile_data["questions"]
    # We would then subtract from 6 until target <= 0
    for qa in questions_data:
        if qa["in_circulation"] == True:
            qa["in_circulation"] = False
            target -= qa["average_times_shown_per_day"]
        if target <= 0:
            user_profile_data["questions"] = questions_data
            return user_profile_data
        
def update_questions_in_circulation(user_profile_data: dict) -> dict: #Private Function
    '''
    Determines whether questions should be pulled from circulation or added into circulation, based on the desired daily questions settings and the current average daily shown stat
    after determination is made, function calls either remove_questions_from_circulation() or add_questions_into_circulation
    '''
    # Load in user data
    settings_data = user_profile_data["settings"]
    stats_data = user_profile_data["stats"]
    
    # assign variables with user data we are working with.
    average_daily_questions = stats_data["average_questions_per_day"]
    desired_daily_questions = settings_data["desired_daily_questions"]
    print(f"Current average daily questions being shown is: {average_daily_questions}")
    print(f"Current desired daily questions to be shown is: {desired_daily_questions}")
    if average_daily_questions >= desired_daily_questions * 1.10: # 10% threshold, so if desired is 100, if we exceed 110 the script will reduce the amount of questions in circulation
        user_profile_data = remove_questions_from_circulation(average_daily_questions, desired_daily_questions, user_profile_data) # For ease of reading, seperate the removal process into its own function
        print("Finished updating list of circulating questions")
        return user_profile_data
    elif average_daily_questions < desired_daily_questions: # Indicating we need to add questions
        user_profile_data = add_questions_into_circulation(average_daily_questions, desired_daily_questions, user_profile_data)
        print("Finished updating list of circulating questions")
        return user_profile_data
    else:
        print("Finished updating list of circulating questions")
        return None

##################################################################


