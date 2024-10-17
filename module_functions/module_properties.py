def update_module_all_subjects_property(module_data):
    subject_list = []
    for unique_id, question_object in module_data["questions"].items():
        for subject in question_object["subject"]:
            if subject not in subject_list:
                subject_list.append(subject)
        module_data["all_subjects"] = subject_list
    return module_data



def update_module_all_concepts_property(module_data):
    concepts_covered = {} # {concept: num_times_mentioned}
    for unique_id, question_object in module_data["questions"].items():
        if question_object.get("related") != None: # Catch TypeError if question_object is missing the "related" field
            for concept in question_object["related"]:
                # Parse out double brackets
                if concept.startswith("[[") and concept.endswith("]]"):
                    concept = concept[2:-2]
                if concept not in concepts_covered:
                    concepts_covered[concept] = 1
                else:
                    concepts_covered[concept] += 1
        module_data["concepts_covered"] = concepts_covered
    return module_data



def update_module_primary_subject_property(module_data):
    subject_counts = {}
    for unique_id, question_object in module_data["questions"].items():
        for subject in question_object["subject"]:
            if subject not in subject_counts:
                subject_counts[subject] = 1
            else:
                subject_counts[subject] += 1
    # We got an error because one of the modules had an empty questions list,
    # To handle for this we will check if the questions field has data or is still an empty dictionary
    # If it is an empty dictionary, we will immediately return module_data, otherwise we'll be able to determine a primary subject
    if module_data["questions"] == {}:
        return module_data
    module_data["primary_subject"] = str(max(subject_counts, key=subject_counts.get)).title()
    return module_data