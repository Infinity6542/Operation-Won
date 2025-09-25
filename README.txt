**RUNNING THE BACKEND**
|----------------------------------------------------------------------------|
|   NOTE: there is a backend hosted at http://192.9.165.5:8000 (NOT HTTPS)   |
|----------------------------------------------------------------------------|
1. Make sure you have Go and Docker OR Podman installed.
2. From this directory, run "cd server"
3. Run "podman compose up --build -d" OR "docker compose up --build -d"
4. If there are any errors, you can install Docker/Podman Compose. If not, it'll be ready soon!
   Run "docker logs opwon_server" or "podman logs opwon_server" depending on what you have to read the logs

**RUNNING THE FRONTEND**
|----------------------------------------------------------------------------|
|   NOTE: only do this method if the APK does not work for whatever reason   |
|----------------------------------------------------------------------------|
1. Make sure that:
- USB debugging is enabled on your Android device
- The Android device is connected to your device
- Make sure you have Android Studio and the necessary tools installed
- Make sure you have the Flutter SDK installed
2. Run "flutter doctor" to ensure that everything is good for **ANDROID**
3. From this directory, run "cd client"
4. See your devices by running "flutter devices". Note the ID of your Android device
5. Run "flutter run -d [ID]". Replace [ID] with the ID of your device from the previous step
6. Wait for the build (it can take a long time)
7. Once the building and installing finishes, your app is ready! Check your phone for the app