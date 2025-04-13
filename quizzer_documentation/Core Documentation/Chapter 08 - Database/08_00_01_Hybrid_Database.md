### How is the data stored?
The Quizzer platform implements a hybrid local-central database architecture to optimize performance while maintaining data integrity. All behavioral task data is primarily stored in a relational database utilizing SQLite, which provides a lightweight yet robust solution integrated directly with the Dart programming environment. This implementation enables efficient local data operations while minimizing external dependencies.

As the project scales, the database architecture will transition to a distributed system with clear separation between local and central data repositories. Client applications will maintain local SQLite instances containing only the subset of data required for immediate user operations, while a centralized server infrastructure will house the complete dataset for analytical processing and machine learning operations. This synchronization pattern ensures data consistency while reducing bandwidth requirements and enabling offline functionality for end users.

The database is designed to be as interconnected as possible. Each table will have properly detailed primary and foreign keys. There are many tables to discuss, including userProfile_uuid Tables, tables for data collection as detailed in section [[03_03_breakdown_of_behavioral_tasks|3-2]], and tables relating to the internal workings of the software itself.

This design aligns with the "Offline - Online" philosophy described in section [[04_03_UI_UX_Philosophy|4-2 UI UX Philosophy]].

### Core Database Tables
The database structure includes several interconnected table categories:
1. **User Profile Tables**: Storing user authentication data, preferences, and learning progress metrics.
2. **Behavioral Task Data Tables**: As detailed in section 03_02, these include:
    - Source Material Table: Storing academic content with proper citations
    - Source Material Key Term Table: Linking key concepts to source materials
    - Question-Answer Pair Table: Storing generated learning units
    - Subject Concept Classification Results Table: Recording classification metadata
    - Answer Questions Task Results: Tracking user interactions with learning content

Records of entry will fall into two categories, these categories define how they will be synced with the central database:
- Dynamic Records
	- dynamic records are such records that are required for regular function, or those records that have their fields updated over time. Examples include question-answer pairs, user-question-answer-pairs, question modules, user profiles, and other such records
- Static Records
	- static records are time-stamped entries marking specific data at a specific time and should not ever be changed, these records generally are not needed for normal operation of the program

Two fields define how sync function behaves

| field                            | Type      | description                                                                                                                                                                                                                                                                                                                                                   |
| -------------------------------- | --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| has_been_synced_with_central_db: | bool      | boolean indicating whether this record has been synced properly with the central DB. This flag is used for Static records and dynamic records. For dynamic records, anytime a change is made locally to this record it should also ensure this flag is set to False indicating to the sync background process that it should sync this record with the cloud. |
| last_sync_with_central_db        | date_time | The last time this record was synced, time-stamp as reported by the server, not by the user machine. This field allows us to see which record is most up to date, newest. Using that information we can decide whether we need to get data from the central db or send an update to that central db                                                           |

All records across all tables should include one or both of these fields. However to ensure simplicity, the sync background function will add these fields if not present. If the field is missing we can assume that both are False, Null