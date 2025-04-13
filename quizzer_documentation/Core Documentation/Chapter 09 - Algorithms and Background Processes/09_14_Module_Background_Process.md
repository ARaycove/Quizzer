The modules are stored in the [[08_04_Modules_Table]]

A number of the fields, namely subjects, concepts and question_ids are derived from the [[08_01_01_Question_Answer_Pair_Table]].

For this reason the module build process will become a background process that is called whenever a question_answer pair is added or edited:
Special calculations should be made so that when a question_answer pair is added the entire table doesn't need to be rebuilt. Instead we can check what the old subjects and concepts were and undo individual changes then conduct the new changes