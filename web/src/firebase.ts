import { initializeApp } from 'firebase/app';
import { getDatabase } from 'firebase/database';
import { initializeAppCheck, ReCaptchaV3Provider } from 'firebase/app-check';

// Firebase configuration from environment variables
const firebaseConfig = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY,
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN,
  databaseURL: import.meta.env.VITE_FIREBASE_DATABASE_URL,
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID,
  storageBucket: import.meta.env.VITE_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID,
  appId: import.meta.env.VITE_FIREBASE_APP_ID
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);

// Initialize App Check
// Get your reCAPTCHA v3 site key from Firebase Console -> App Check
const appCheckSiteKey = import.meta.env.VITE_FIREBASE_APP_CHECK_SITE_KEY;

if (appCheckSiteKey) {
  try {
    initializeAppCheck(app, {
      provider: new ReCaptchaV3Provider(appCheckSiteKey),
      isTokenAutoRefreshEnabled: true // Automatically refresh tokens
    });
    console.log('✅ App Check initialized successfully');
  } catch (error) {
    console.error('❌ App Check initialization failed:', error);
    console.error('Site key being used:', appCheckSiteKey);
  }
} else {
  console.warn('⚠️ App Check is not configured. Add VITE_FIREBASE_APP_CHECK_SITE_KEY to .env.local');
}

// Initialize Realtime Database
export const database = getDatabase(app);

