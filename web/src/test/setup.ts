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

// A window with enough of a URL and an event target to test the router, which
// reads `location.pathname`, writes through `history`, and then announces the
// change with a `popstate` event of its own.
const locationMock = {
  origin: 'http://localhost:5174',
  pathname: '/',
  search: '',
  href: 'http://localhost:5174/',
};

function applyUrl(url: string) {
  const next = new URL(url, locationMock.origin);
  locationMock.pathname = next.pathname;
  locationMock.search = next.search;
  locationMock.href = next.href;
}

const historyMock = {
  length: 1,
  pushState: vi.fn((_state: unknown, _title: string, url?: string | URL | null) => {
    if (url != null) applyUrl(String(url));
    historyMock.length += 1;
  }),
  replaceState: vi.fn((_state: unknown, _title: string, url?: string | URL | null) => {
    if (url != null) applyUrl(String(url));
  }),
};

const listeners = new Map<string, Set<(event: unknown) => void>>();

define('window', {
  history: historyMock,
  location: locationMock,
  addEventListener: (type: string, listener: (event: unknown) => void) => {
    if (!listeners.has(type)) listeners.set(type, new Set());
    listeners.get(type)!.add(listener);
  },
  removeEventListener: (type: string, listener: (event: unknown) => void) => {
    listeners.get(type)?.delete(listener);
  },
  dispatchEvent: (event: { type: string }) => {
    listeners.get(event.type)?.forEach((listener) => listener(event));
    return true;
  },
});
