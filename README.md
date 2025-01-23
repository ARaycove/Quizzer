# A quizzer_v04 Flet app

To run the app:

```
1. install VS CODE
2. install docker for vs code
3. install dev containers for vs code
4. sudo docker-compose up --build
5. ensure container is running:
        docker ps / sudo docker ps
6. command p to bring up the pallet
    - search for attach to running container
    - click option
7. Wait for vs code instance to initialize
8. Enter the src directory for the project
    -cd code/src/
9. To build
    - flet build apk
    - flet build web
10. To Run the App
    - flet run main.py

Got a build error?
Try this:
1. docker-compose down --volumes
2. docker-compose up --build # Try again
If not working still
3. docker system prune -af --volumes #This wipes everything and will force reinstallation of all dependencies
4. docker-compose up --build
```