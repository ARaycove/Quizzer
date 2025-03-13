class UserProfileQuestionDB:
    '''
    Subclass to store all UserQuestionObjects
    '''
    pass
class UserProfileSettingsDB:
    '''
    Subclass to store all User Settings
    '''
    pass
    # Could potentionally make a sub-subclass called setting
class UserProfileStatsDB:
    '''
    Subclass to storre all User statistics
    '''
    pass

class UserProfile:
    '''
    Quizzer Storage Object for all User data,
    new instances of UserProfile will be generated for every user
    User Profiles are broken down into three sections
    - Questions
        - In-circulation questions
        - Reserve Questions (not yet introduced but eligible to be introduced)
        - Deactivated Questions (as disabled by the user, either individually or through disabling a module)
    - Settings
        - Allows the user to alter the behavior of Quizzer to adapt to individual preferences
    - Stats
        - Holds a majority of User data, primarily usage data, that is not directly related to a user's history with an individual question.
        - There are additional stats held for individual questions, showing the users individual usage history with each question they introduced to.
    '''