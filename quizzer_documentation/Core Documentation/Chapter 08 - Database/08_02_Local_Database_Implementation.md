
### Database Implementation Schema

%% Complete set of tables created upon initialization %%
%% All tables will be created on first initialization, as empty tables with all fields put in %%

%% Get and set functions for individual elements %%
%% Validation functions to embed into set functions %%

%% Get whole row functions for tables, which would be an aggregate call using all get functions %%

%% No remove function will be implemented, all data should remain preserved %%

We will CSV for fields that may have multiple values, such as secondary languages, social links, specializations, etc

Every record regardless of table should have a local update time, and/or a boolean indicating whether it has been synced with the cloud. This would depend on whether said table contains records meant to be modified. For example the question_answer pair table would just indicate the time it was synced with the cloud server and whether or not it has or hasn't. However since it's not meant to be modified after entry, no such repeat synchronization needs to take place. However the user profile data would need to be synced periodically, and granularly. Such tables when updated would flip the boolean indicating it is up to date with the server to false. This is further described in section [[09_05_Data_Synchronization_Background_Process]].

Some information to be collected:

Noise Level at time of question-answer pair answer attempt
Location at time of question-answer pair answer attempt

