// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import { AsyncLocalStorage } from 'node:async_hooks';

/**
 * Marks the narrow call path that is allowed to write catalogue-managed room
 * fields.
 *
 * This is deliberately NOT a global flag. A module-level boolean would be
 * switched on for the whole process and every concurrent request would inherit
 * it — exactly the "unsafe global bypass switch" this must not be. An
 * AsyncLocalStorage scope is bound to one asynchronous call tree: only code
 * that the sync itself invoked runs inside it, an admin-panel request never
 * does, and the scope disappears automatically when the sync returns.
 */

const storage = new AsyncLocalStorage<true>();

/** Runs `fn` on the internal catalogue write path. */
export function runAsCatalogSync<T>(fn: () => Promise<T>): Promise<T> {
  return storage.run(true, fn);
}

/** True only inside {@link runAsCatalogSync}. */
export function isCatalogSync(): boolean {
  return storage.getStore() === true;
}
