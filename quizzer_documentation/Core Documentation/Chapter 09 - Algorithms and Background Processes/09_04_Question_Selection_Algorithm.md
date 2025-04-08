The Question Selection Algorithm will follow some simple rules, the integration of these rules is the larger issue to solve at the moment.
1. Questions should be placed in a buffer. The question buffer records the last n amount of questions answered. This will be the basis on which we can determine other criteria.
2. The Question Buffer should not exceed j, where j is the total of the average times in the question selection buffer. If five questions reside in the buffer, one with an average time of 120 seconds, and the other four with an average time of 10 seconds to answer, then average time to answer the questions in the buffer is 160 seconds. If the threshold is 180 seconds in the buffer then the next question chosen would be remove a question from the buffer reducing the total amount of time, if the removed question in our example is 10 seconds then the buffer is now 150 seconds. The threshold left in the buffer would be 30 seconds, meaning the next question chosen may not exceed 30 seconds average time to answer.
3. Selected Questions should never be selected twice in row, more simply the question selected may not already exist in the buffer. If five questions exist in the buffer then those five questions are ineligible to be chosen as the next presented question.
4. Selected Questions must be selected from those currently marked as in_circulation, these may only be placed into circulation using the [[09_03_Question_Circulation_Selection_Algorithm|Question_Circulation_Algorithm]]
5. Questions selected should have some sort of weight system. The further a question is beyond it's due date the more likely it should be selected. Questions that lie within the users interest set should be weighted more heavily than those outside.
6. If the Question Selection Algorithm can't find any eligible questions should trigger the Question Circulation Algorithm, then select the question that it chooses.
7. The Selection Algorithm should have a counter system that increments every time a question is answered, when the counter hits a defined point, the Question Circulation Algorithm should be triggered to add a new question into a circulation. The defined point is likely in the range of 10 - 20 questions answered.

The old algorithm is rudimentary but is in the old code base as follows:
- This old script only serves as an example and proof of the inadequacy of it. This algorithm needs an overall
```python
def get_next_question(user_profile_data, amount_of_rs_one_questions):
    '''
    Selection Algorithm
    determines which question will be shown to the user next based on their profile data and settings
    Currently ensures that presented questions prioritize questions with lower revision streaks over questions with higher streaks
    '''
    # Now based on the random_weight we will choose a question within the range
    user_questions: dict = user_profile_data["questions"]["in_circulation_is_eligible"]
    # To ensure questions are not presented back to back, we will shuffle the order of the keys every time we pick a new question
    user_questions = helper.shuffle_dictionary_keys(user_questions)
    for i in range(1, 101):
        for question_id, question_object_user_data in user_questions.items():
            check_var = question_object_user_data["revision_streak"]
            due_date = helper.convert_to_datetime_object(question_object_user_data["next_revision_due"])
            overdue = False
            print(f"Selected question with RS of {check_var}")
            return question_id  
            # Questions that are not close to the due date won't be presented
            # If the question hits this condition it indicates it is overdue for revision, beyond the acceptable margin

            # Define which questions get immediate priority
            # Questions that have just been added go first
            if i == 1:
                if check_var == 1:
                    print(f"Selected question with RS of {check_var}")
                    return question_id
            # Questions that the user is still actively learning (has not gone to medium-long term memory)
            elif i == 2:
                if check_var <= 6:
                    print(f"Selected question with RS of {check_var}")
                    return question_id         
            # Questions the user is overdue for answering (At risk of forgetting that information)           
            elif i == 3:   
                if helper.within_twenty_four_hours(helper.convert_to_datetime_object(question_object_user_data["next_revision_due"])) == False:
                    overdue = True
                    print(due_date)
                if overdue == True:
                    print(f"Selected question with RS of {check_var}")
                    print(f"Question is overdue")
                    return question_id
            # All other questions
            elif i >= 4:
                print(f"Selected question with RS of {check_var}")
                return question_id    
```