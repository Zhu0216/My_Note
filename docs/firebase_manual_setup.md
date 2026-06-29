# Firebase Manual Setup

Firebase CLI login is blocked on this machine, so the app is prepared for
manual Firebase connection.

## Firebase Console

Create or open a Firebase project, then add these apps:

- Android package name: `com.allinone.mynote`
- iOS bundle id: `com.allinone.mynote`
- Web app nickname: `my_note_web`

Enable these products when ready:

- Authentication
- Cloud Firestore
- Firebase Storage
- Cloud Messaging
- Hosting

## Current Project Status

Already added in this repo:

- Flutter Firebase SDK packages:
  - `firebase_core`
  - `firebase_auth`
  - `cloud_firestore`
  - `firebase_storage`
  - `firebase_messaging`
- Firebase initialization guard in `lib/main.dart`
- Placeholder app settings in `lib/firebase_options.dart`
- Android package name: `com.allinone.mynote`
- Android permissions:
  - `INTERNET`
  - `POST_NOTIFICATIONS`
- Firebase project config files:
  - `firebase.json`
  - `.firebaserc.example`
  - `firestore.rules`
  - `firestore.indexes.json`
  - `storage.rules`

Not connected yet:

- Real Firebase project id
- Real Web/Android/iOS Firebase app ids and API keys
- Enabled Auth providers
- Created Firestore database
- Created Storage bucket
- FCM sender/VAPID setup
- Hosting deploy target

## Flutter Config

Open `lib/firebase_options.dart` and replace every `REPLACE_ME` value with the
values shown in Firebase Console app settings.

Until those values are replaced, the app keeps running in local-only mode and
skips `Firebase.initializeApp()`.

## Optional Native Config Files

You may also download native config files from Firebase Console:

- Android: place `google-services.json` at `android/app/google-services.json`
- iOS: place `GoogleService-Info.plist` at `ios/Runner/GoogleService-Info.plist`

The current Flutter initialization uses Dart `FirebaseOptions`, so these files
are not required for the first local Firebase-ready build, but they are useful
later for native services and store release polish.

## Required Values

From Firebase Console app settings, fill these fields in
`lib/firebase_options.dart`:

- `apiKey`
- `appId`
- `messagingSenderId`
- `projectId`
- `authDomain` for Web
- `storageBucket`
- `iosBundleId` when iOS is added

Copy `.firebaserc.example` to `.firebaserc`, then replace
`REPLACE_WITH_FIREBASE_PROJECT_ID` with the Firebase project id.

## Product Checklist

Authentication:

- Enable Email/Password first.
- Later enable Google and Apple sign-in.
- For Google sign-in on Android, add SHA-1/SHA-256 fingerprints in Firebase
  Console.

Cloud Firestore:

- Create a Firestore database.
- Start with production mode.
- Publish `firestore.rules`.
- Store user data under `/users/{uid}/...`.

Firebase Storage:

- Create the default Storage bucket.
- Publish `storage.rules`.
- Store files under `/users/{uid}/...`.

FCM:

- Android permission is already declared.
- Later request notification permission in-app.
- For Web push, create a Web Push certificate/VAPID key and add a web service
  worker before calling `FirebaseMessaging.getToken()`.

Hosting:

- Build with `flutter build web`.
- `firebase.json` already points Hosting to `build/web`.
- Deploy later with `firebase deploy --only hosting` after CLI auth or a valid
  service account/token is available.
