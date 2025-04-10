User Authentication is an important aspect of user data protection. We will not build our own authentication and therefore will require an initial internet to register new user's. When an email and password are submitted the email will be stored locally and the email and password will get sent to the user authentication service. currently we will use Oauth Authentication for email - password verification.

Once a user is registered on a local device they can login with just their email. Otherwise if it's a new device the system will not be able to find the user profile inside their device and therefore will require login through authentication.

We will also have a security feature where if the user is logged out for more than a week that they will be required to login again through the authentication service. The goal is still to be able to provide an offline friendly experience while maintaining security. This login will only occur if the user is logged out for a sufficient amount of time, this is not a timer where every 7 days they are required to log in. They are only required to login if logged out for too long.

