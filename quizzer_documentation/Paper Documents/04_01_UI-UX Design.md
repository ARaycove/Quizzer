# Offline - Online
Quizzer is designed to be fully functional even without an internet connection. Today it's very easy to use cloud services to quickly write and deploy an application. Everything can quickly connect to the cloud, and the process quickly becomes like piecing Lego's together. However the problem comes when more advanced or customized features need to be implemented. For this reason Quizzer will avoid relying upon 3rd party services and cloud architecture if at all possible. This decision also comes out of need to avoid predatory pricing that often accompanies such SaaS conveniences. They tend to lure a person or organization in with free tier pricing, then once things get busy the prices go up drastically and because the application was built around this service it becomes difficult or even impossible to then switch providers. So again for these reasons, if a system can be written and developed locally it shall be done locally and from "scratch". While this may extend the development time, we believe this method will reduce complexity in the long run, increase maintainability, and reduce costs, paying massive dividends well into the future.
# Flexible UI Layout
Quizzer is designed to have a flexible UI that adjusts to the device it is ran upon. Certain tasks are only truly suited for desktop environments where more screen real estate is necessary. Tasks that will likely be desktop exclusive will be the source material entry, and question-answer generation. Since these tasks are more difficult to perform on mobile phones and tablets without the aid of a keyboard. However it may be a good design choice to include the option to perform these tasks on mobile devices, even if they are not ideal. For mobile phones such tasks would have a disclaimer that they are better suited to be completed on Desktop versions of the application.

# Page - Function Flow
Wireframes of the layout are planned using Obsidian's excalidraw community plugin, the option used is to make the wire framed designs look basic and very rough. These are not the final artistic renditions but rather the general design and layout of the UI elements. If you wish to view the full wireframe, you'll need to download obsidian, download this repo locally, then using obsidian create a new vault with this repo as the folder directory. Once you've done that you should go to settings, community plugins and search for excalidraw, install excalidraw, then ensure you enable the plugin for this vault. Otherwise individual images are in this document.

This section will also detail what functionality is to be executed, further details of those functions and what they do will be in the next section 04_03_Functions.
# Initial Startup
When Quizzer is loaded using the executable the database should initialize. A background process should start that syncs the question-answer pair table with the one stored centrally. In addition any attempt records for various tasks that are not necessary for execution of behavioral tasks (described in 03_02_breakdown_of_behavioral_tasks), should be synced with the central database, once it's been confirmed that records were properly uploaded, those records will get removed from the local instance of the application. Leaving behind only what is necessary for regular operation
# Login Page
The Login page shall consist of the Quizzer logo, an email entry field, password entry field, a submission button, several social automated logins (including google, facebook, gitlab, github, etc.), and a Sign Up page button.

## Data Fields
- Email Field
	- The user's email address they signed up with
- Password Field
	- The user's password in order to access their account
## Buttons
Submit:
	Takes in the Email and Password field and sends it to the authentication service ([[04_02_Functions#User Authentication Functions|info]])
Social Login (n):
	There will be n social media login buttons where n is the number of platforms the Quizzer team has integrated with. Clicking on these login buttons will initialize the login process through the associated platform. [[04_02_Functions#Social Media Login Authentication|info]]
New User Signup:
	This button is a simple link that redirects the program to the New User Signup Page
![[Pasted image 20250402212253.png]]
# Add New User Page
Quizzer Logo should blend, not clip
![[Pasted image 20250402225334.png]]
# Main Interface 
Upon logging in the user should get sent directly into the main interface of the program. This interface will be the core Answer Questions behavioral task. The user will be presented with a question, the center of the screen should be one large button, when clicked the interface should show an extremely fast animation, then the answer to that question should appear. At the bottom of the page will be 5 buttons (Yes(sure), Yes(unsure), (?), No(sure), No(unsure)) to reflect the options in the Answer Questions behavioral task. Clicking the center button should bring up three additional options to select. (Did not Read Question Properly), (Not Interested In This), (Too Advanced for Me)
## Buttons
### Yes(sure)
Text for this 
# Menu Interface
The menu will contain links to individual behavioral task interfaces, to the settings page, and to any other pages listed. The menu interface is merely the navigation element of quizzer
## Buttons
### Logout Button
-> Returns the user to the Login Page