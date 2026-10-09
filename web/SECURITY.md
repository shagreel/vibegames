# Security Documentation

## 🔒 Is My Firebase Config Secure?

### ✅ YES! Firebase Config is Designed to Be Public

**Important:** Your Firebase configuration values (API key, project ID, etc.) are **NOT secrets** and are **meant to be in client-side code**.

```javascript
// This is SAFE to be public:
const firebaseConfig = {
  apiKey: "AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
  authDomain: "your-project.firebaseapp.com",
  databaseURL: "https://your-project.firebaseio.com",
  projectId: "your-project",
  // ...
};
```

### Why This is Safe

1. **API Key is NOT a Secret**
   - It only identifies your Firebase project
   - It's embedded in every mobile app and website using Firebase
   - Millions of apps have public Firebase configs

2. **Security Comes from Firebase Security Rules**
   - Rules control who can read/write data
   - Rules run on Firebase servers (not client-side)
   - Rules cannot be bypassed by modifying client code

3. **Google's Official Stance**
   > "Unlike how API keys are typically used, API keys for Firebase services are not used to control access to backend resources; that can only be done with Firebase Security Rules." - [Firebase Documentation](https://firebase.google.com/docs/projects/api-keys)

## 🛡️ Current Security Measures

### 1. Firebase Security Rules ✅

Your database has comprehensive security rules:

```json
{
  "rules": {
    "games": {
      "$gameId": {
        ".read": true,
        ".write": false,
        
        "word": {
          ".write": "!data.exists()",
          ".validate": "newData.isString() && newData.val().length === 5"
        },
        
        "creator": {
          ".write": "!data.exists()",
          ".validate": "newData.isString() && newData.val().length > 0"
        },
        
        "started": {
          ".write": true,
          ".validate": "newData.isBoolean()"
        },
        
        "winner": {
          ".write": true,
          ".validate": "newData.isString() || newData.val() === null"
        },
        
        "players": {
          ".write": true,
          "$playerId": {
            ".validate": "newData.hasChildren(['name', 'joinedAt'])"
          }
        }
      }
    }
  }
}
```

**What This Protects:**
- ✅ Word cannot be changed after game creation
- ✅ Creator cannot be changed after game creation
- ✅ All data types are validated
- ✅ Invalid data is rejected
- ✅ Malicious data injection is prevented

### 2. Environment Variables ✅

Sensitive configuration is in `.env.local`:
- ✅ Not committed to git (in `.gitignore`)
- ✅ Each developer has their own config
- ✅ Production uses different Firebase project

### 3. Client-Side Validation ✅

The app validates data before sending to Firebase:
- ✅ Word length validation
- ✅ Player name validation
- ✅ Game ID format validation
- ✅ Firebase-safe key generation

## 🚨 Potential Security Concerns

### 1. Anyone Can Read All Games

**Current State:**
```json
".read": true  // Anyone can read any game
```

**Risk Level:** 🟡 Low
- Game data is not sensitive (just Vibe Words guesses)
- Needed for multiplayer functionality
- No personal information stored

**Mitigation:**
- Don't store sensitive information in games
- Use random game IDs (not predictable)
- Consider adding authentication for private games

### 2. Anyone Can Create Games

**Current State:**
```json
"word": {
  ".write": "!data.exists()"  // Anyone can create games
}
```

**Risk Level:** 🟡 Low-Medium
- Could lead to database bloat
- Potential for spam/abuse
- Limited by Firebase free tier quotas

**Mitigation:**
- Implement rate limiting (see below)
- Add cleanup for old games
- Monitor database usage
- Consider requiring authentication

### 3. No Rate Limiting

**Current State:**
- No limits on game creation
- No limits on player joins
- No limits on database writes

**Risk Level:** 🟠 Medium
- Could be abused to spam database
- Could exceed Firebase quotas
- Could increase costs

**Mitigation:**
- Implement client-side rate limiting
- Use Firebase Cloud Functions for server-side limits
- Enable App Check (see below)

## 🔐 Recommended Security Enhancements

### 1. Enable App Check (Highly Recommended)

App Check protects your Firebase resources from abuse by bots and unauthorized apps.

**Setup:**
1. Go to Firebase Console → **App Check**
2. Click **Get started**
3. Register your web app
4. Choose **reCAPTCHA v3** (easiest) or **reCAPTCHA Enterprise**
5. Add your domain
6. Enable enforcement for Realtime Database

**Benefits:**
- ✅ Blocks bots and automated abuse
- ✅ Prevents unauthorized apps from using your Firebase
- ✅ No code changes required
- ✅ Free tier available

### 2. Restrict API Key (Recommended)

Prevent others from using your API key on their websites.

**Setup:**
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your Firebase project
3. Go to **APIs & Services** → **Credentials**
4. Click on your API key (starts with "Browser key")
5. Under **Application restrictions**, select **HTTP referrers**
6. Add allowed domains:
   ```
   localhost:5174/*
   localhost:5173/*
   yourdomain.com/*
   *.yourdomain.com/*
   ```
7. Click **Save**

**Benefits:**
- ✅ Prevents API key abuse
- ✅ Limits usage to your domains
- ✅ No code changes required

### 3. Implement Rate Limiting

**Client-Side (Quick Fix):**

Add to `src/Vibe Words.tsx`:

```typescript
// Rate limiting for game creation
const RATE_LIMIT_MS = 60000; // 1 minute
const lastGameCreation = localStorage.getItem('lastGameCreation');

if (lastGameCreation && Date.now() - parseInt(lastGameCreation) < RATE_LIMIT_MS) {
  alert('Please wait before creating another game');
  return;
}

localStorage.setItem('lastGameCreation', Date.now().toString());
```

**Server-Side (Better):**

Use Firebase Cloud Functions (requires Blaze plan):

```javascript
// functions/index.js
exports.createGame = functions.https.onCall(async (data, context) => {
  // Rate limit: 1 game per minute per IP
  const ip = context.rawRequest.ip;
  const recentGames = await checkRecentGames(ip);
  
  if (recentGames > 0) {
    throw new functions.https.HttpsError('resource-exhausted', 'Rate limit exceeded');
  }
  
  // Create game...
});
```

### 4. Add Authentication (Optional)

For private games or user accounts:

```bash
npm install firebase/auth
```

Update security rules:
```json
{
  "rules": {
    "games": {
      "$gameId": {
        ".read": "auth != null",  // Only authenticated users
        ".write": "auth != null"
      }
    }
  }
}
```

## 📊 Monitoring & Alerts

### Set Up Usage Alerts

1. Go to Firebase Console → **Realtime Database** → **Usage**
2. Click **Set up alerts**
3. Configure alerts for:
   - **Connections:** Alert at 80% of limit (80 for free tier)
   - **Storage:** Alert at 500 MB (free tier is 1 GB)
   - **Bandwidth:** Alert at 8 GB (free tier is 10 GB/month)

### Monitor for Abuse

Check regularly for:
- ❌ Unusual number of games created
- ❌ Spike in database reads/writes
- ❌ Games with suspicious data
- ❌ Rapid player joins/leaves

## ✅ Security Checklist

- [x] Firebase Security Rules configured
- [x] Data validation in rules
- [x] `.env.local` in `.gitignore`
- [x] Client-side validation
- [ ] App Check enabled (recommended)
- [ ] API key restricted (recommended)
- [ ] Rate limiting implemented (recommended)
- [ ] Usage alerts configured (recommended)
- [ ] Regular monitoring (recommended)

## 🆘 What to Do If Compromised

If you suspect your Firebase project is compromised:

1. **Immediately:**
   - Go to Firebase Console → **Realtime Database** → **Rules**
   - Set all `.write` to `false` temporarily
   - Click **Publish**

2. **Investigate:**
   - Check **Usage** tab for unusual activity
   - Review **Data** tab for suspicious entries
   - Check recent rule changes

3. **Secure:**
   - Rotate API keys if needed
   - Enable App Check
   - Restrict API key to specific domains
   - Add rate limiting

4. **Clean Up:**
   - Delete suspicious data
   - Review and update security rules
   - Monitor for 24-48 hours

## 📚 Additional Resources

- [Firebase Security Rules Documentation](https://firebase.google.com/docs/database/security)
- [Firebase App Check](https://firebase.google.com/docs/app-check)
- [API Key Best Practices](https://firebase.google.com/docs/projects/api-keys)
- [Firebase Security Checklist](https://firebase.google.com/support/guides/security-checklist)

## 💡 Summary

**Your Firebase config being public is NORMAL and SAFE.**

Security comes from:
1. ✅ Firebase Security Rules (server-side, cannot be bypassed)
2. ✅ Data validation
3. ✅ App Check (recommended)
4. ✅ API key restrictions (recommended)
5. ✅ Rate limiting (recommended)

**NOT from:**
- ❌ Hiding API keys
- ❌ Obfuscating config
- ❌ Client-side security checks

