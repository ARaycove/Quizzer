First calls [[07_01_03_verifyUserProfileTable()]]

Calls [[07_01_04_generateUserUUID()]] and assigns the value in local scope

Collects the email field and username

Initializes the role field to "base_user"

account_status initializes to active

last_login initializes to Null 

Collects the time stamp for creation, to current time

All other fields default to Null upon new creation
- Fields like settings, and notification preferences will be initialized when first used
- This means a number of fields will initialize on first login not on account creation.


