/**
 * Mock implementation of @tauri-apps/api/event for web development
 */

import { __webEventListeners } from './core';

export async function listen<T>(event: string, callback: (data: { payload: T }) => void): Promise<() => void> {
  console.log(`[Web Mock] Listening to event: ${event}`);
  
  if (!__webEventListeners.has(event)) {
    __webEventListeners.set(event, []);
  }
  
  __webEventListeners.get(event)!.push(callback);
  
  // Return unsubscribe function
  return () => {
    const listeners = __webEventListeners.get(event);
    if (listeners) {
      const index = listeners.indexOf(callback);
      if (index > -1) {
        listeners.splice(index, 1);
      }
    }
  };
}

export async function emit(event: string, payload?: any): Promise<void> {
  console.log(`[Web Mock] Emitting event: ${event}`, payload);
  // In web mode, we don't need to emit to backend
  return;
}