def defines_initial_module_data(module_name=str) -> dict:
    '''
    This function returns a dictionary containing default data so that all new modules are uniform
    '''
    initial_module_data = {}
    # Series of initial properties
    initial_module_data["module_name"] = module_name
    initial_module_data["description"] = "No Description Provided"
    initial_module_data["author"] = ""
    initial_module_data["is_a_quizzer_module"] = True #
    initial_module_data["activated"] = True
    initial_module_data["primary_subject"] = ""
    initial_module_data["all_subjects"] = []
    initial_module_data["concepts_covered"] = []
    initial_module_data["questions"] = {}
    initial_module_data["mindmap"] = {}
    


    # This is a return statement 
    # :'( <--- this is a crying face in case you didn't get the joke.
    return initial_module_data