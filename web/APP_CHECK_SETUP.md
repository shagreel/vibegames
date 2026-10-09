# App Check Setup Checklist

## ✅ What You've Done

You've enabled App Check in the Firebase Console! Great job! 🎉

## 📋 Next Steps to Complete Setup

### Step 1: Get Your reCAPTCHA Site Key

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Click **App Check** in the left sidebar
4. Find your web app in the list
5. You should see your **reCAPTCHA site key** displayed

It looks like this:
```
6LeXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

**Copy this key!** You'll need it for the next step.

### Step 2: Add Site Key to .env.local

1. Open your `.env.local` file (in the root of your project)
2. Add this line at the end:

```bash
VITE_FIREBASE_APP_CHECK_SITE_KEY=6LeXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

Replace `6LeXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX` with your actual site key from Step 1.

**Your .env.local should now look like:**
```bash
VITE_FIREBASE_API_KEY=AIzaSy...
VITE_FIREBASE_AUTH_DOMAIN=your-project.firebaseapp.com
VITE_FIREBASE_DATABASE_URL=https://your-project-default-rtdb.firebaseio.com
VITE_FIREBASE_PROJECT_ID=your-project
VITE_FIREBASE_STORAGE_BUCKET=your-project.appspot.com
VITE_FIREBASE_MESSAGING_SENDER_ID=123456789
VITE_FIREBASE_APP_ID=1:123456789:web:abc123
VITE_FIREBASE_APP_CHECK_SITE_KEY=6LeXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

### Step 3: Enable Enforcement (IMPORTANT!)

App Check is enabled but not enforced yet. To actually protect your database:

1. Go to Firebase Console → **App Check**
2. Find **Realtime Database** in the list of services
3. Click the **Enforce** button (or toggle enforcement ON)
4. Confirm the action

**⚠️ Warning:** After enforcement is enabled, only requests with valid App Check tokens will be allowed!

### Step 4: Restart Your Dev Server

```bash
# Stop the current server (Ctrl+C)
# Then restart:
npm run dev
```

### Step 5: Verify It's Working

1. Open your app in the browser
2. Open DevTools (F12) → Console tab
3. Look for App Check messages

**✅ Success looks like:**
```
Firebase App Check initialized successfully
```

**❌ Error looks like:**
```
App Check token refresh failed
```

If you see errors:
- Double-check your site key in `.env.local`
- Make sure you restarted the dev server
- Verify the site key matches what's in Firebase Console

## 🔍 Troubleshooting

### Error: "App Check token refresh failed"

**Cause:** Site key is missing or incorrect

**Fix:**
1. Verify `VITE_FIREBASE_APP_CHECK_SITE_KEY` is in `.env.local`
2. Check the site key matches Firebase Console → App Check
3. Restart dev server

### Error: "Requests are being blocked"

**Cause:** Enforcement is enabled but App Check isn't initialized

**Fix:**
1. Make sure site key is in `.env.local`
2. Restart dev server
3. Clear browser cache and reload

### Warning: "App Check is not configured"

**Cause:** Site key is missing from `.env.local`

**Fix:**
1. Add `VITE_FIREBASE_APP_CHECK_SITE_KEY` to `.env.local`
2. Restart dev server

### App works in dev but not in production

**Cause:** Production domain not added to reCAPTCHA

**Fix:**
1. Firebase Console → App Check → Your web app
2. Click **Manage** next to reCAPTCHA v3
3. Add your production domain
4. Redeploy your app

## 📊 Verification Checklist

- [ ] App Check enabled in Firebase Console
- [ ] reCAPTCHA site key copied
- [ ] Site key added to `.env.local` as `VITE_FIREBASE_APP_CHECK_SITE_KEY`
- [ ] Enforcement enabled for Realtime Database
- [ ] Dev server restarted
- [ ] No App Check errors in browser console
- [ ] App can create and join games successfully

## 🎯 What App Check Does

### ✅ Protects Against:
- 🤖 Bots and automated abuse
- 🚫 Unauthorized apps using your Firebase
- 💣 DDoS attacks
- 📊 Quota abuse
- 🔓 API key theft/misuse

### ✅ How It Works:
1. Your app requests an App Check token from Firebase
2. reCAPTCHA v3 verifies the request is from a real user
3. Firebase issues a short-lived token
4. All database requests include this token
5. Firebase validates the token before allowing access
6. Tokens auto-refresh every hour

### ✅ User Experience:
- **No CAPTCHAs to solve!** reCAPTCHA v3 runs invisibly
- **No login required** - works for anonymous users
- **No performance impact** - tokens are cached
- **Seamless** - users won't notice anything different

## 🔐 Security Status After Setup

| Security Measure | Status |
|-----------------|--------|
| Firebase Security Rules | ✅ Configured |
| Data Validation | ✅ Enabled |
| App Check | ✅ Enabled |
| Bot Protection | ✅ Active |
| API Key Restrictions | 🟡 Recommended |
| Rate Limiting | 🟡 Recommended |

## 📚 Additional Resources

- [Firebase App Check Docs](https://firebase.google.com/docs/app-check)
- [reCAPTCHA v3 Docs](https://developers.google.com/recaptcha/docs/v3)
- [SECURITY.md](SECURITY.md) - Full security documentation
- [FIREBASE_SETUP.md](FIREBASE_SETUP.md) - Complete Firebase setup guide

## 🆘 Need Help?

If you're stuck:

1. Check the browser console for specific error messages
2. Verify all environment variables are set correctly
3. Make sure you restarted the dev server after adding the site key
4. Check Firebase Console → App Check to verify your app is registered

## ✨ You're Almost Done!

Just add the site key to `.env.local` and restart your dev server, and you'll have enterprise-grade security protecting your Vibe Words game! 🎉

