# Login_Attempt Table

### Description
The Login_Attempt Table records user authentication attempts in the system. When a user attempts to log in, they are required to enter an email and password, which is authenticated through Google's Firebase Authentication. This table tracks these login events and their outcomes for security and auditing purposes.

### Fields
Primary_Key = login_attempt_id
Foreign_Key = user_id

| Key              | Data Type | Description                                                                             |
| ---------------- | --------- | --------------------------------------------------------------------------------------- |
| login_attempt_id |           | Unique identifier for each login attempt                                                |
| user_id          |           | Reference to the user making the login attempt                                          |
| email            |           | Email address used for the login attempt                                                |
| timestamp        |           | The date and time when the login attempt occurred                                       |
| status_code      | bool      | Whether the authentication attempt was successful, failed, idled, or any other response |
| ip_address       |           | IP address from which the login was attempted                                           |
| device_info      |           | Information about the device used for the login attempt                                 |
