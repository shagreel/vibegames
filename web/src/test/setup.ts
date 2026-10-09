import { vi } from 'vitest';

// `localStorage`, `navigator` and `window` are getter-only on the global in
// current jsdom, so plain assignment throws. Install them with defineProperty
// instead.
function define(name: string, value: unknown) {
  Object.defineProperty(globalThis, name, {
    value,
    configurable: true,
    writable: true,
  });
}

// Mock localStorage
const localStorageMock = (() => {
  let store: Record<string, string> = {};

  return {
    getItem: (key: string) => store[key] || null,
    setItem: (key: string, value: string) => {
      store[key] = value.toString();
    },
    removeItem: (key: string) => {
      delete store[key];
    },
    clear: () => {
      store = {};
    },
  };
})();

define('localStorage', localStorageMock);

// Mock navigator (for clipboard API)
define('navigator', {
  clipboard: {
    writeText: vi.fn(() => Promise.resolve()),
  },
});

// Mock window.history / window.location
define('window', {
  history: {
    replaceState: vi.fn(),
    pushState: vi.fn(),
  },
  location: {
    origin: 'http://localhost:5174',
    pathname: '/',
    search: '',
  },
});
