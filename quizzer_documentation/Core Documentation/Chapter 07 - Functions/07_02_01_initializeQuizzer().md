Calls initialization functions

[[07_01_01_loadDatabase()]]
- Initialize the following tables (Only those directly related the functionality needed for the home page, other tables will be loaded and intialized when their corresponding pages are first loaded by the user, meaning if a user never uses a particular feature, the database items for that page won't be needlessly added):
	- [[08_01_01_Question_Answer_Pair_Table]]
	- [[08_01_02_User_Question_Relationship_Table]]
	- [[08_01_03_Question_Answer_Attempts_Table]]
	- [[08_01_04_Question_Flags_Table]]
	- [[08_04_Modules_Table]]
- Begins [[09_13_Question_Selection_Background_Process]]
- [[07_05_backgroundNoiseBackgroundProcess()]]
- [[07_05_dataSynchronizationBackgroundProcess()]]
- [[07_05_geographicLocationBackgroundProcess()]]

