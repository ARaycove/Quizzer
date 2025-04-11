# User_Profile_Table

### Description
The User_Profile_Table stores comprehensive information about users registered on the platform. It contains mandatory registration information, automatically generated account data, optional personal information that enhances the learning experience, user preferences, and key statistical metrics. This centralized table maintains the complete user profile for authentication, personalization, and statistical tracking purposes.
### Fields

Primary_Key = uuid Foreign_Key = None

| Key                          | Data Type    | Description                                                                                                                                               |
| ---------------------------- | ------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| uuid                         | String(uuid) | Auto-generated universal unique identifier for the user                                                                                                   |
| email                        | String       | The user's email address used at registration (mandatory)                                                                                                 |
| username                     | String       | Display name that the user wishes to share with other users (mandatory)                                                                                   |
| role                         | String       | User role (admin, base_user, contributor, etc.), defaults to "base_user"                                                                                  |
| account_status               | String       | Status of the account (active, inactive, suspended, paid_user, sponsor, lifetime, etc.)                                                                   |
| account_creation_date        | date_time    | The exact time of registration                                                                                                                            |
| last_login                   | date_time    | The exact time of the most recent login                                                                                                                   |
| profile_picture              | String(path) | Path to the user's uploaded profile picture                                                                                                               |
| birth_date                   | date         | The self-reported date of birth for the user                                                                                                              |
| address                      | String       | User's self-reported location or city/region                                                                                                              |
| job_title                    | String       | The self-reported job title of the user                                                                                                                   |
| education_level              | String       | The self-reported education level of the user                                                                                                             |
| specialization               | String(CSV)  | List of certificates and other skills reported by the user                                                                                                |
| teaching_experience          | Boolean      | Indicates whether the user has teaching background                                                                                                        |
| primary_language             | String       | The primary language of the user                                                                                                                          |
| secondary_languages          | String(CSV)  | List of additional languages the user can speak                                                                                                           |
| study_schedule               | String(JSON) | The self-reported preferred study times for the user                                                                                                      |
| social_links                 | String(CSV)  | Links to academic profiles (optional)                                                                                                                     |
| achievement_sharing          | Boolean      | Whether progress can be shared publicly                                                                                                                   |
| interest_data                | String(JSON) | Data regarding user's interests, including psych assessments and subject ratings                                                                          |
| settings                     | String(JSON) | Key-value pairs for all setting values on the account                                                                                                     |
| notification_preferences     | String(JSON) | The user's settings for notifications                                                                                                                     |
| learning_streak              | Integer      | Consecutive days of platform use (for gamification)                                                                                                       |
| total_study_time             | Double       | Cumulative time spent studying on the platform                                                                                                            |
| total_questions_answered     | Integer      | Total questions the user has answered                                                                                                                     |
| average_session_length       | Double       | Average time spent on the platform for any given login session                                                                                            |
| peak_cognitive_hours         | String(CSV)  | Times of day when user demonstrates highest recall/performance                                                                                            |
| health_data                  | String(JSON) | Records (last_seven_days of sleep), (last_seven_days step count), other health metrics that can be synced                                                 |
| recall_accuracy_trends       | String(JSON) | For each domain of knowledge, records the general accuracy trend for that domain                                                                          |
| content_portfolio            | String(CSV)  | A record of content the user has produced, which would be useful in deriving prior knowledge                                                              |
| activation_status_of_modules | String(JSON) | {module_name: bool} The key marked the modules name and the boolean indicates whether it is active or not                                                 |
| completion_status_of_modules | String(JSON) | {module_name: double} For each module determine what percentage of the questions contained in that module are currently in circulation for the given user |
Note: Password is not stored in this table as authentication is handled through Firebase Authentication.

Some suggestions:
**interleaving_effectiveness**: Metrics showing how the user performs when material is interleaved across topics versus blocked by topic

**attention_span_metrics**: Derived data showing optimal engagement length before performance decreases