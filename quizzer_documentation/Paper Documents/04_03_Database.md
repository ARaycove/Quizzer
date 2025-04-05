The database is designed as a highly structured relational database that is to be as interconnected as possible. Each table will have properly detailed primary and foreign keys. There are many tables to discuss, including userProfile_uuid Tables, tables for data collection as detailed in section 03_02, and tables relating to the internal workings of the software itself.
### Core Database Design Philosophy
Quizzer's database architecture follows a hybrid approach that prioritizes both offline functionality and data integrity. Unlike many modern applications that default to cloud storage solutions, Quizzer implements a SQLite-based local database system that allows users to operate the application fully when disconnected from the internet, aligning with the "Offline - Online" philosophy described in section 04_01.

This decision stems from a deliberate stance against dependency on third-party services and cloud architecture to avoid the "predatory pricing" that often accompanies SaaS conveniences. As stated in section 04_01, such services "tend to lure a person or organization in with free tier pricing, then once things get busy the prices go up drastically." By developing the database system locally and "from scratch," the Quizzer platform aims to "reduce complexity in the long run, increase maintainability, and reduce costs, paying massive dividends well into the future."
### Core Database Tables

The database structure includes several interconnected table categories:

1. **User Profile Tables**: Storing user authentication data, preferences, and learning progress metrics.
2. **Behavioral Task Data Tables**: As detailed in section 03_02, these include:
    - Source Material Table: Storing academic content with proper citations
    - Source Material Key Term Table: Linking key concepts to source materials
    - Question-Answer Pair Table: Storing generated learning units
    - Subject Concept Classification Results Table: Recording classification metadata
    - Answer Questions Task Results: Tracking user interactions with learning content
### Database Implementation Schema

%% Complete set of tables created upon initialization %%
%% All tables will be created on first initialization, as empty tables with all fields put in %%

%% Get and set functions for individual elements %%
%% Validation functions to embed into set functions %%

%% Get whole row functions for tables, which would be an aggregate call using all get functions %%

%% No remove function will be implemented, all data should remain preserved %%
# User Profile Tables:
We will CSV for fields that may have multiple values, such as secondary languages, social links, specializations, etc
## User_Profile_Table
When a user first signs up for the platform we will collect some mandatory information, then ask the user to disclose some further information about themselves to improve the learning experience. The data absolutely required at sign up only includes the email, username and password:
	email:                 The user's email address used at registration
	username:              display name that the user wishes to share with other users
	password:   Not stored locally, authenticated using firebase authentication

Once the user signs up, some information will be generated for their account automatically:
	uuid:                  auto-generated univeral unique id
	role:                  admin, base_user, contributor, etc.
	account_status:        active, inactive, suspended, paid_user, sponsor, lifetime, etc.
	account_creation date: the exact time of registration
	last_login:            the exact time of the most recent login

There is a large bank of personal information that could be collected about a person that may or may not be impactful in the functioning of memory retention. The following metrics will default to established default value. Upon logging in for the first time the user will get a series of tutorial questions and encouragement to enter their user_profile and enter some information about themselves.
	profile_picture:    picture of the user, if they choose to upload
	birth_date:            the self-reported date of birth for the user
	address:               the locational data garnered if the user gives location permissions, otherwise allow the user to enter their primary residence themselves (When asking the user for this data, we need to clarify that at most we would at for a city or general region in which they live, and that this data helps us develop a better product)
	job_title:             the self-reported job title of the user
	education_level:       the self-reported education level of the user
	specialization:        the self-reported list of certificates and other skills listed by the user
	teaching_experience:   Boolean or details about teaching background
	primary_language:      the primary language of the user
	secondary_langauges:   json object containing a list of any additional languages that the user might be able to speak
	study_schedule:        the self-reported preferred study times for the user
	social links:          JSON object with links to academic profiles (optional) (We can use socials to scrape for user data, with their permission)
	achievement_sharing:   Boolean for whether progress can be shared publicly
	interest_data:         json_object containing all data regarding the user's interests, this includes psych assessments, self-reported subject ratings, and other such data (Interest Data points will be collected through a user-interest inventory assessment)
	settings:              json_object containing key-value pairs for all setting values on the account
	notification_preferences: The user's settings for notifications specifically
There are also many statistical metrics that can be tracked, while the bulk of these will stored in the User Statistics table, the most recent values will be stored in their profile record
	learning_streak:                     Integer tracking consecutive days of platform use (for gamification)
	total_study_time:                   Cumulative time spent studying on the platform
	total_questions_answered:   Total questions the user has answered











learning_streak



## User_Login_Attempt Table
When a user logs in they are required to enter an email and a password. Authentication for email/password will be handled through Google's Firebase Authentication. The following information was also be asked for at the user sign up page: 

Metadata will also be recorded inside the user profile table, account_creation_data, account_status, last_login, role (defaulting to "base"), preferences.

When stored locally all of this data can be stored in a single row of data, centrally stored, each record of the central userProfile table will be an entire User Profile and all of their data