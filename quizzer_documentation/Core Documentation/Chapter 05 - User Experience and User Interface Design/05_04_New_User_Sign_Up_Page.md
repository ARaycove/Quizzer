# Add New User Page
While we could request a very large block of data at the sign up page, we will avoid doing so. This voluntary information will be presented later in the [[05_13_My_Profile_Page|My Profile Page]].
## Rule of thumb
- All UI elements should have uniform height
- Height of UI elements should be of a maximum of 25px and scale to the height of the screen
- Width of UI elements should not exceed the width of the logo
## Images
- Logo should be displayed prominently at the top of the screen
- Logo should have no top or side margins applied
## Fields
- Email Entry
	- the email address the user is signing up with
- Username Entry
	- the desired public name the user wants
- Password Entry
	- The password the user would like to sign up with
- Password Confirmation Entry
	- Confirm the password is correct

## Buttons
- Back Button
	- Redirects the user back to the Login Page
- Submit Button
	- Calls an internal function void submission() which does two things:
		- passes the email and username to the [[07_01_02_createNewUserProfile(email, username)]] function
		- waits for a response
		- If failure notifies the user and remains on the Signup Page
		- If Success notifies the user and redirects to the Login Page
