If the folder is numbered the functionality inside is not available to the UI

Only the logger and session manager should ever be revealed to the UI, the rest of the functionality is wrapped into the SessionManager, which serves as the API