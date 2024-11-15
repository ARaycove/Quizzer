import system_data_question_stats
# This .py file handles functions involving moving questions between the 5 piles
# Unsorted Pile
# Deactivated Pile
# Reserve Bank Pile
# In circulation not eligible
# In circulation is eligible

def verify_module_questions_exist_in_user_profile(name_of_module, user_profile_data, all_module_data):
    pass

def update_circulating_non_eligible_questions(user_profile_data, question_object_data):
    '''
    Looks over the questions in the "in_circulation_non_eligible" pile, updates them, and if any are eligible moves them to the "in_circulation_is_eligible" pile
    '''
    print(f"def update_circulating_non_eligible_questions(user_profile_data, question_object_data)")
    questions_to_remove_from_not_eligible_pile = []
    questions_data = user_profile_data["questions"]["in_circulation_not_eligible"].copy()
    for unique_id, question_object in questions_data.items():
        question_object = system_data_question_stats.update_user_question_stats(question_object, unique_id, user_profile_data, question_object_data)
        write_data = {unique_id: question_object}
        if question_object["is_eligible"] == True:
            # If the question is now eligible then add it to the is_eligible pile
            user_profile_data["questions"]["in_circulation_is_eligible"].update(write_data)
            questions_to_remove_from_not_eligible_pile.append(unique_id)

    print(f"    Moving {len(questions_to_remove_from_not_eligible_pile)} questions from in_circulation_not_eligible pile to in_circulation_is_eligible pile")
    for unique_id in questions_to_remove_from_not_eligible_pile:
        # We've already added this pair to the is_eligible pile, therefore we need to delete it from the in_circulation_not_eligible pile
        del user_profile_data["questions"]["in_circulation_not_eligible"][unique_id]
    return user_profile_data

