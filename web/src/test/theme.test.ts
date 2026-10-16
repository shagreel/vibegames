import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import {
  THEME_KEY,
  applyTheme,
  resolvedTheme,
  setThemePreference,
  subscribeTheme,
  systemTheme,
  themePreference,
  watchTheme,
} from '../theme';

/**
 * The appearance is one value for the whole suite, and the only interesting
 * things about it are that it is remembered, that `system` really does follow
 * the device, and that a device which changes its mind is noticed.
 *
 * The test setup's `window` is a hand-made object with no `matchMedia`, so the
 * module has to survive that too — which is what the first case checks.
 */
describe('theme', () => {
  beforeEach(() => {
    localStorage.clear();
    delete (window as unknown as { matchMedia?: unknown }).matchMedia;
  });

  afterEach(() => {
    delete (window as unknown as { matchMedia?: unknown }).matchMedia;
  });

  it('is dark when the device says nothing and nothing has been chosen', () => {
    expect(themePreference()).toBe('system');
    expect(systemTheme()).toBe('dark');
    expect(resolvedTheme()).toBe('dark');
  });

  it('remembers the choice', () => {
    setThemePreference('light');
    expect(localStorage.getItem(THEME_KEY)).toBe('light');
    expect(themePreference()).toBe('light');
    expect(resolvedTheme()).toBe('light');
  });

  it('falls back to system for a value it does not recognise', () => {
    localStorage.setItem(THEME_KEY, 'sepia');
    expect(themePreference()).toBe('system');
  });

  it('follows the device while the choice is system', () => {
    const media = { matches: true };
    (window as unknown as { matchMedia: unknown }).matchMedia = () => media;
    expect(systemTheme()).toBe('light');
    expect(resolvedTheme('system')).toBe('light');

    // A device that turns dark at sunset.
    media.matches = false;
    expect(resolvedTheme('system')).toBe('dark');
  });

  it('ignores the device once a choice has been made', () => {
    (window as unknown as { matchMedia: unknown }).matchMedia = () => ({ matches: true });
    expect(resolvedTheme('dark')).toBe('dark');
    expect(resolvedTheme('light')).toBe('light');
  });

  it('tells everything showing the choice when it changes', () => {
    const seen = vi.fn();
    const stop = subscribeTheme(seen);

    setThemePreference('light');
    expect(seen).toHaveBeenCalledTimes(1);

    setThemePreference('dark');
    expect(seen).toHaveBeenCalledTimes(2);

    stop();
    setThemePreference('system');
    expect(seen).toHaveBeenCalledTimes(2);
  });

  it('follows a device that changes its mind, and only while on system', () => {
    const listeners = new Set<() => void>();
    let matches = false;
    (window as unknown as { matchMedia: unknown }).matchMedia = () => ({
      get matches() {
        return matches;
      },
      addEventListener: (_: string, listener: () => void) => listeners.add(listener),
      removeEventListener: (_: string, listener: () => void) => listeners.delete(listener),
    });

    const seen = vi.fn();
    const stop = subscribeTheme(seen);
    const unwatch = watchTheme();

    // The device turns light: nothing was chosen, so everything should hear.
    matches = true;
    for (const listener of listeners) listener();
    expect(seen).toHaveBeenCalledTimes(1);

    // A choice has been made, so the device no longer gets a say.
    setThemePreference('dark');
    expect(seen).toHaveBeenCalledTimes(2);
    matches = false;
    for (const listener of listeners) listener();
    expect(seen).toHaveBeenCalledTimes(2);

    stop();
    unwatch();
    expect(() => resolvedTheme()).not.toThrow();
    expect(() => applyTheme()).not.toThrow();
  });
});
