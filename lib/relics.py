# def generate_test_file():
#     questions_data = helper.get_question_data()
#     new_structure = {}
#     for question in questions_data:
#         del question["id"]
#         question["file_name"] = question["file_name"][1:]
#         new_structure[question["file_name"]] = question
#     with open("modules_question_test.json", "w+") as f:
#         json.dump(new_structure, f, indent=4)

# def get_subjects(): #Private Function
#     '''returns a set of subjects based on the subject key in questions.json
#     lets you know all the subjects that exist in questions.json'''
#     settings_data = helper.get_settings_data()
#     subject_set = set([])
#     for subject in settings_data["subject_settings"]:
#         subject_set.add(subject)
#     return subject_set

def print_all_hexidecimal_characters():
    '''
    Prints out a feed of all hexidecimal characters, 50 per line
    '''
    var = 0 
    for i in range(5000):
        print(chr(i), end="")
        var += 1
        if var >= 50:
            print()
            var = 0