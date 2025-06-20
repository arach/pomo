/**
 * Mock implementation of @tauri-apps/api/webviewWindow for web development
 */

export function getCurrentWebviewWindow() {
  return {
    async close() {
      console.log('[Web Mock] Window close (no-op)');
    },
    async minimize() {
      console.log('[Web Mock] Window minimize (no-op)');
    },
    async show() {
      console.log('[Web Mock] Window show (no-op)');
    },
    async setFocus() {
      console.log('[Web Mock] Window setFocus (no-op)');
    },
  };
}