# Login Page
The Login page shall consist of the Quizzer logo, an email entry field, password entry field, a submission button, several social automated logins (including google, facebook, gitlab, github, etc.), and a Sign Up page button.

## Data Fields
- Email Field
	- The user's email address they signed up with
- Password Field
	- The user's password in order to access their account
## Buttons
Submit:
	Takes in the Email and Password field and sends it to the authentication service ([[07_03_Functions#User Authentication Functions|info]])
Social Login (n):
	There will be n social media login buttons where n is the number of platforms the Quizzer team has integrated with. Clicking on these login buttons will initialize the login process through the associated platform. [[07_03_Functions#Social Media Login Authentication|info]]
New User Signup:
	This button is a simple link that redirects the program to the New User Signup Page
![[LoginPage.png]]
