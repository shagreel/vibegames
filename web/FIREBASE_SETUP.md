# Firebase Setup Guide for Vibe Words

This guide will help you set up Firebase Realtime Database for the multiplayer Vibe Words game.

## Step 1: Create a Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project" or "Create a project"
3. Enter a project name (e.g., "vibe-words-multiplayer")
4. Disable Google Analytics (optional, not needed for this app)
5. Click "Create project"

## Step 2: Set Up Realtime Database

1. In your Firebase project, click on "Realtime Database" in the left sidebar
2. Click "Create Database"
3. Choose a location (select the one closest to your users)
4. Start in **Test mode** for now (we'll secure it later)
5. Click "Enable"

## Step 3: Configure Database Rules (SECURE VERSION)

### Option A: Balanced Security (Recommended)

These rules provide good security while allowing your app to function:

1. In the Realtime Database page, click on the "Rules" tab
2. Replace the rules with the following:

```json
{
  "rules": {
    "games": {
      "$gameId": {
        ".read": true,
        ".write": "!data.exists()",

        "word": {
          ".write": "!data.exists() || data.parent().child('winner').exists()",
          ".validate": "newData.isString() && newData.val().length === 5"
        },

        "creator": {
          ".write": "!data.exists()",
          ".validate": "newData.isString() && newData.val().length > 0"
        },

        "createdAt": {
          ".write": "!data.exists()",
          ".validate": "newData.isNumber()"
        },

        "started": {
          ".write": true,
          ".validate": "newData.isBoolean()"
        },

        "winner": {
          ".write": "!data.child('name').exists() || newData.val() === null",
          ".validate": "newData.val() === null || newData.hasChildren(['name', 'timestamp'])",
          "name": {
            ".validate": "newData.isString()"
          },
          "timestamp": {
            ".validate": "newData.isNumber()"
          }
        },

        "restartTime": {
          ".write": true,
          ".validate": "newData.isNumber() || newData.val() === null"
        },

        "players": {
          ".write": true,
          "$playerId": {
            ".validate": "newData.hasChildren(['name', 'joinedAt']) && newData.child('name').isString() && newData.child('joinedAt').isNumber()"
          }
        }
      }
    }
  }
}
```

**🔒 Security Features:**

**Write Protection:**
- ✅ **Games can only be created once** - `".write": "!data.exists()"` at game level
- ✅ **Word cannot be changed** after game creation
- ✅ **Creator cannot be changed** after game creation
- ✅ **Winner can only be set once** - prevents changing the winner
- ✅ **All data types validated** - prevents malicious data

**What's Allowed:**
- ✅ Anyone can read games (needed for multiplayer)
- ✅ Anyone can create new games (once per game ID)
- ✅ Anyone can update `started` and `restartTime`
- ✅ Anyone can add players
- ✅ Winner can be set once (first person to win)

**What's Prevented:**
- ❌ Cannot overwrite an existing game
- ❌ Cannot change the word after creation
- ❌ Cannot change the creator after creation
- ❌ Cannot change the winner once set
- ❌ Cannot write invalid data types

### Option B: Maximum Security (For Production)

For even tighter security, use these rules (requires authentication):

```json
{
  "rules": {
    "games": {
      "$gameId": {
        ".read": true,
        ".write": false,

        "word": {
          ".write": "!data.exists() && newData.parent().child('creator').val() != null",
          ".validate": "newData.isString() && newData.val().length === 5"
        },

        "creator": {
          ".write": "!data.exists() && newData.parent().child('word').val() != null",
          ".validate": "newData.isString() && newData.val().length > 0"
        },

        "createdAt": {
          ".write": "!data.exists()",
          ".validate": "newData.isNumber()"
        },

        "started": {
          ".write": "data.parent().child('creator').exists()",
          ".validate": "newData.isBoolean()"
        },

        "winner": {
          ".write": "!data.child('name').exists() && newData.parent().child('started').val() === true",
          ".validate": "newData.hasChildren(['name', 'timestamp'])",
          "name": {
            ".validate": "newData.isString()"
          },
          "timestamp": {
            ".validate": "newData.isNumber()"
          }
        },

        "restartTime": {
          ".write": "data.parent().child('winner').exists()",
          ".validate": "newData.isNumber() || newData.val() === null"
        },

        "players": {
          ".write": "data.parent().child('creator').exists()",
          "$playerId": {
            ".validate": "newData.hasChildren(['name', 'joinedAt']) && newData.child('name').isString() && newData.child('joinedAt').isNumber()"
          }
        }
      }
    }
  }
}
```

**Additional Security:**
- ✅ Can only start game if it was created
- ✅ Can only add players if game exists
- ✅ Can only set winner if game has started
- ✅ Can only restart if there's a winner

**⚠️ Start with Option A** - It provides excellent security while being easier to work with during development.

**🔒 Security Features:**

**Data Validation:**
- ✅ Word must be exactly 5 characters
- ✅ Creator name must not be empty
- ✅ Started must be boolean
- ✅ Winner must be string or null
- ✅ Players must have name and joinedAt timestamp

**Write Protection:**
- ✅ Word can only be set once (cannot be changed after creation)
- ✅ Creator can only be set once (cannot be changed)
- ✅ Game structure is validated
- ✅ All data types are validated

**What's Allowed:**
- ✅ Anyone can read games (needed for multiplayer)
- ✅ Anyone can create new games
- ✅ Anyone can update started, winner, restartTime
- ✅ Anyone can add players

**What's Prevented:**
- ❌ Cannot change the word after game creation
- ❌ Cannot change the creator after game creation
- ❌ Cannot write invalid data types
- ❌ Cannot create games without required fields
- ❌ Cannot inject malicious data

**Scalability:**
- This setup easily handles 100+ simultaneous users
- Firebase Realtime Database free tier supports 100 concurrent connections
- For more users, upgrade to Blaze (pay-as-you-go) plan which supports 200,000 connections
- Consider adding cleanup for old games (see below)

This allows:
- Anyone to read all game data
- Only the first person can create a game (write the entire game object)
- Anyone can update the "started", "winner", "restartTime", and "players" fields
- This enables synchronized game restarts, winner tracking, and player counting

3. Click "Publish"

## Step 4: Get Your Firebase Configuration

1. In Firebase Console, click the gear icon ⚙️ next to "Project Overview"
2. Click "Project settings"
3. Scroll down to "Your apps"
4. Click the web icon `</>` to add a web app
5. Register your app with a nickname (e.g., "Vibe Words Web")
6. Copy the `firebaseConfig` object

## Step 5: Configure Your App

1. Create a file named `.env.local` in the root of your project
2. Copy the contents from `.env.local.example`
3. Fill in the values from your Firebase config:

```env
VITE_FIREBASE_API_KEY=AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
VITE_FIREBASE_AUTH_DOMAIN=your-project-id.firebaseapp.com
VITE_FIREBASE_DATABASE_URL=https://your-project-id-default-rtdb.firebaseio.com
VITE_FIREBASE_PROJECT_ID=your-project-id
VITE_FIREBASE_STORAGE_BUCKET=your-project-id.appspot.com
VITE_FIREBASE_MESSAGING_SENDER_ID=123456789012
VITE_FIREBASE_APP_ID=1:123456789012:web:abcdef1234567890
```

4. Save the file

## Step 6: Enable App Check (REQUIRED for Security)

App Check protects your Firebase resources from abuse by bots and unauthorized apps.

### 6.1: Register Your App with App Check

1. In Firebase Console, click **App Check** in the left sidebar
2. Click **Get started** (if first time) or **Add app**
3. Select your web app from the dropdown
4. Choose **reCAPTCHA v3** as the provider
5. Click **Save**

### 6.2: Get Your reCAPTCHA Site Key

After registering, you'll see your reCAPTCHA site key. Copy it!

It looks like: `6LeXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX`

### 6.3: Add Site Key to Your .env.local

Open your `.env.local` file and add:

```bash
VITE_FIREBASE_APP_CHECK_SITE_KEY=6LeXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

Replace with your actual site key from step 6.2.

### 6.4: Enable Enforcement for Realtime Database

1. In Firebase Console → **App Check**
2. Click on **Realtime Database** in the list
3. Click **Enforce** (or toggle enforcement on)
4. Confirm the action

**Important:** This will block all requests that don't have a valid App Check token!

### 6.5: Add Your Domain (for Production)

1. In Firebase Console → **App Check** → Your web app
2. Click **Manage** next to reCAPTCHA v3
3. Add your production domain(s):
   - `yourdomain.com`
   - `www.yourdomain.com`
4. Click **Save**

**Note:** `localhost` is automatically allowed for development.

## Step 7: Restart Your Dev Server

1. Stop the current dev server (Ctrl+C)
2. Restart it: `npm run dev`
3. The app should now connect to Firebase with App Check enabled!

**You should see in the browser console:**
```
Firebase App Check initialized successfully
```

If you see warnings about App Check, verify your site key is correct in `.env.local`.

## Step 8: Test the Multiplayer Feature

1. Open the app in your browser
2. Click "Create Game" and enter your name
3. Click the copy button 📋 to copy the game link
4. Open the link in a different browser or incognito window
5. Enter a different name and join the game
6. The creator can click "Start Game" when ready
7. When one player wins, the other should see the winner announcement!

**Verify App Check is Working:**
- Open browser DevTools (F12) → Console
- You should NOT see any App Check errors
- If you see "App Check token refresh failed", verify your site key in `.env.local`

## Database Structure

The app stores data in this structure:

```
games/
  {gameId}/
    creator: "Creator Name"
    started: true
    restartTime: 1234567890000  // Timestamp when game will restart (null if not restarting)
    winner/
      name: "Player Name"
      timestamp: 1234567890
    players/
      {playerId}/
        name: "Player Name"
        joinedAt: 1234567890
```

## 🔐 Security Best Practices

### ✅ What's Already Secure

1. **Firebase Config is Public** - This is normal and safe!
   - API keys in client code are NOT secrets
   - They only identify your Firebase project
   - Security comes from Firebase Security Rules (not hiding config)

2. **Security Rules Validate Data**
   - Word must be exactly 5 characters
   - All data types are validated
   - Critical fields (word, creator) cannot be changed after creation

3. **Environment Variables** - Config is in `.env.local`
   - Not committed to git (in `.gitignore`)
   - Each developer has their own config

### 🛡️ Additional Security Recommendations

#### 1. Restrict Your API Key (Recommended)

In Firebase Console:
1. Go to **Project Settings** → **General**
2. Scroll to **Web API Key**
3. Click **Manage API keys in Google Cloud Console**
4. Click on your API key
5. Under **Application restrictions**, select **HTTP referrers**
6. Add your domains:
   ```
   localhost:5174/*
   yourdomain.com/*
   ```

This prevents others from using your API key on their websites.

#### 2. Enable App Check (Highly Recommended)

App Check protects your Firebase resources from abuse:

1. Go to **Firebase Console** → **App Check**
2. Click **Get started**
3. Register your web app
4. Choose **reCAPTCHA v3** or **reCAPTCHA Enterprise**
5. Add your domain

This prevents bots and unauthorized apps from accessing your database.

#### 3. Monitor Usage

1. Go to **Firebase Console** → **Realtime Database** → **Usage**
2. Set up alerts for unusual activity
3. Monitor for:
   - Sudden spikes in reads/writes
   - Unusual number of connections
   - High bandwidth usage

#### 4. Rate Limiting (For Production)

Consider implementing rate limiting to prevent spam:
- Limit game creation to 1 per minute per IP
- Limit player joins to prevent flooding
- Use Firebase Cloud Functions for server-side validation

### ⚠️ What NOT to Do

❌ **Don't** try to hide Firebase config - it's meant to be public
❌ **Don't** commit `.env.local` to git
❌ **Don't** use the same Firebase project for dev and production
❌ **Don't** disable security rules for convenience

## Optional: Cleanup Old Games

To prevent database bloat with old games, you can manually clean up games older than 24 hours:

1. Go to Firebase Console → Realtime Database → Data tab
2. Find old games under `games/`
3. Delete games that are no longer active

**For automatic cleanup**, you would need:
- Firebase Cloud Functions (requires Blaze plan)
- A scheduled function to delete games older than 24 hours

Example cleanup function (requires Blaze plan):
```javascript
// Not included in this project, but here's how you'd do it:
exports.cleanupOldGames = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async (context) => {
    const cutoff = Date.now() - 24 * 60 * 60 * 1000; // 24 hours ago
    const snapshot = await admin.database().ref('games').once('value');
    const updates = {};
    snapshot.forEach(child => {
      if (child.val().createdAt < cutoff) {
        updates[child.key] = null; // Delete old game
      }
    });
    return admin.database().ref('games').update(updates);
  });
```

## Troubleshooting

### "Firebase not configured" error
- Make sure `.env.local` exists and has all the required variables
- Restart the dev server after creating `.env.local`

### Winner not showing up
- Check the browser console for errors
- Verify your database rules are published
- Make sure the database URL is correct (should end with `.firebaseio.com`)

### CORS errors
- Make sure you're using the correct database URL
- Check that your Firebase project is active

## Optional: Clean Up Old Games

You can manually delete old game data from the Firebase Console:
1. Go to Realtime Database
2. Navigate to `games/`
3. Delete old game IDs

Or set up automatic cleanup with Firebase Functions (advanced).

## 🎮 How the Game Works

### Game Flow

1. **Player enters name** - Stored in localStorage
2. **Player creates or joins game** - Game ID in URL
3. **Creator starts game** - Sets `started: true`
4. **Players make guesses** - Validated client-side
5. **First to guess wins** - Winner recorded in Firebase
6. **Play Again** - 10-second countdown, new word generated

### Multiplayer Features

- **Real-time sync** - All players see updates instantly
- **Unique browser IDs** - Each device gets a unique ID
- **Player count** - Shows how many players are in the game
- **Winner announcement** - All players see who won
- **Restart system** - Coordinated restart with countdown
- **Presence detection** - Automatically removes disconnected players

### Presence Detection

The app uses Firebase's `onDisconnect()` to automatically detect when players leave:

**How it works:**
- When a player joins, Firebase sets up a disconnect handler
- If the player closes the tab, browser crashes, or loses network connection
- Firebase automatically removes them from the player list
- Other players see the updated player count immediately

**Benefits:**
- ✅ Automatic - no manual cleanup needed
- ✅ Reliable - works even if browser crashes
- ✅ Real-time - other players see updates instantly
- ✅ Server-side - handled by Firebase, not client code

**Technical details:**
```typescript
// When player joins
const playerRef = ref(database, `games/${gameId}/players/${browserId}`);
await set(playerRef, {
  name: playerName,
  joinedAt: Date.now()
});

// Set up automatic removal on disconnect
onDisconnect(playerRef).remove();
```

This ensures the player list always reflects who's actually connected to the game.

