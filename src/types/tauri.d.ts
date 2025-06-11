declare global {
  interface Window {
    __TAURI__?: {
      window?: {
        getCurrent(): {
          close(): Promise<void>;
        };
      };
    };
  }
}

export {};