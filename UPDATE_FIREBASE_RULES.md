# How to Update Firebase Security Rules

The app is currently showing a permission error because the Firebase security rules are preventing access to the data. Follow these steps to update the security rules:

## For Firestore Database Rules

1. Go to the [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. In the left sidebar, click on "Firestore Database"
4. Click on the "Rules" tab
5. Replace the existing rules with the following:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow read/write access to all users for the appliances collection
    match /appliances/{document=**} {
      allow read, write: if true;
    }
    
    // Allow read/write access to all users for the relay_states collection
    match /relay_states/{document=**} {
      allow read, write: if true;
    }
    
    // Allow read/write access to all users for the electricity_usage collection
    match /electricity_usage/{document=**} {
      allow read, write: if true;
    }
    
    // Allow read/write access to authenticated users for their own user data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      match /{collection}/{document=**} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }
  }
}
```

6. Click "Publish" to save the changes

## For Realtime Database Rules (if you're using RTDB)

1. Go to the [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. In the left sidebar, click on "Realtime Database"
4. Click on the "Rules" tab
5. Replace the existing rules with the following:

```
{
  "rules": {
    ".read": true,
    ".write": true,
    "relay1": {
      ".read": true,
      ".write": true
    },
    "relay2": {
      ".read": true,
      ".write": true
    },
    "relay3": {
      ".read": true,
      ".write": true
    },
    "relay4": {
      ".read": true,
      ".write": true
    },
    "relay5": {
      ".read": true,
      ".write": true
    },
    "relay6": {
      ".read": true,
      ".write": true
    },
    "relay7": {
      ".read": true,
      ".write": true
    },
    "relay8": {
      ".read": true,
      ".write": true
    },
    "relay9": {
      ".read": true,
      ".write": true
    },
    "relay10": {
      ".read": true,
      ".write": true
    },
    "electricity_usage": {
      ".read": true,
      ".write": true
    }
  }
}
```

6. Click "Publish" to save the changes

## Important Notes

- These rules allow unrestricted access to the specified collections, which is fine for development but not recommended for production.
- For a production app, you should implement more restrictive rules based on authentication and user roles.
- After updating the rules, restart the app to see if the permission error is resolved.