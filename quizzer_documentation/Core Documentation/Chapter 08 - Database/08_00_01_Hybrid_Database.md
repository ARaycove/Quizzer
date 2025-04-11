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