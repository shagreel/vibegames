# Multiplayer Vibe Words

A multiplayer Vibe Words game built with React, TypeScript, Vite, and Firebase Realtime Database.

## ✨ Features

- 🎮 **Multiplayer Support** - Play with friends in real-time
- 📱 **Mobile Responsive** - Works on all devices
- 🔥 **Firebase Integration** - Real-time game synchronization
- 🎯 **14,855 Valid Words** - Comprehensive word dictionary
- 👥 **Player Tracking** - See how many players have joined
- 🏆 **Winner Announcements** - Celebrate victories together
- 🔄 **Play Again** - Restart games with countdown timer
- 📋 **Easy Sharing** - Copy game link to invite friends

## 🧪 Test Suite

Comprehensive test coverage with **41 passing tests**:

```bash
✓ src/test/localStorage.test.ts (9 tests)
✓ src/test/multiDevice.test.ts (7 tests)
✓ src/test/gameLogic.test.ts (17 tests)
✓ src/test/integration.test.ts (8 tests)

Test Files  4 passed (4)
Tests       41 passed (41)
```

See [TESTING.md](TESTING.md) for detailed test documentation.

## 🚀 Getting Started

### Prerequisites

- Node.js v20.9.0 or higher
- npm or yarn
- Firebase account (for multiplayer features)

### Installation

1. Clone the repository
2. Install dependencies:
   ```bash
   npm install
   ```

3. Set up Firebase (see [FIREBASE_SETUP.md](FIREBASE_SETUP.md))

4. Create `.env.local` file with your Firebase credentials:
   ```
   VITE_FIREBASE_API_KEY=your_api_key
   VITE_FIREBASE_AUTH_DOMAIN=your_auth_domain
   VITE_FIREBASE_DATABASE_URL=your_database_url
   VITE_FIREBASE_PROJECT_ID=your_project_id
   VITE_FIREBASE_STORAGE_BUCKET=your_storage_bucket
   VITE_FIREBASE_MESSAGING_SENDER_ID=your_sender_id
   VITE_FIREBASE_APP_ID=your_app_id
   ```

5. Start the development server:
   ```bash
   npm run dev
   ```

## 🧪 Running Tests

```bash
# Run tests in watch mode
npm test

# Run tests once (CI mode)
npm run test:run

# Run tests with UI
npm run test:ui
```

## 📚 Documentation

- [FIREBASE_SETUP.md](FIREBASE_SETUP.md) - Firebase configuration guide
- [TESTING.md](TESTING.md) - Comprehensive test documentation
- [src/test/README.md](src/test/README.md) - Test suite overview

## 🏗️ Built With

- **React 19.2.0** - UI framework
- **TypeScript** - Type safety
- **Vite 7.2.2** - Build tool and dev server
- **Firebase Realtime Database** - Real-time synchronization
- **Vitest** - Testing framework

## 📱 Browser Support

Works on all modern browsers and devices:
- ✅ Chrome (desktop & mobile)
- ✅ Firefox
- ✅ Safari (desktop & mobile)
- ✅ Edge

## 🔐 Privacy & Data

- User data stored in browser localStorage
- Each device gets a unique browser ID
- No personal information collected
- Game data stored in Firebase Realtime Database

## 📄 License

MIT
