# Login Page
The Login page shall consist of the Quizzer logo, an email entry field, password entry field, a submission button, several social automated logins (including google, facebook, gitlab, github, etc.), and a Sign Up page button.
## Rule of thumb
- All UI elements should have uniform height
- Height of UI elements should be of a maximum of 25px and scale to the height of the screen
- Width of UI elements should not exceed the width of the logo
## Images
- Logo should be displayed prominently at the top of the screen
- Logo should have no top or side margins applied
## Data Fields
- Email Field
	- The user's email address they signed up with
- Password Field
	- The user's password in order to access their account
## Buttons
### Submit:
- Takes in the Email and Password field and sends it to the authentication service ([[07_00_Functions#User Authentication Functions|info]])
- Width should be half of the email password field
- Width should be of minimum width 100px
**onPressed**: Calls [[07_10_submitLogin(email, password)|submitLogin()]] function -> 
### Social Login (n):
- There will be n social media login buttons where n is the number of platforms the Quizzer team has integrated with. Clicking on these login buttons will initialize the login process through the associated platform. [[07_00_Functions#Social Media Login Authentication|info]]
- Should be placed in a grid arrangement, depending on size of screen, elements should wrap.
- The Aspect ratio of the social login buttons should be 1:1
- Maximum width/height of social login buttons should be 25px
onPressed: Calls associated login function
%% I haven't explored what logins will be used, but the associated functions will be filled in when this is complete %%
### New User Signup:
- This button is a simple link that redirects the program to the New User Signup Page
- Width should be half of the email and password fields
- Width should be of minimum width 100px
**onPressed**: Calls [[07_02_01newUserSignUp()|newUserSignUp()]] function -> 

![[LoginPage.png]]
