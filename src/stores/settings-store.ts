import { create } from 'zustand';
import { invoke } from '@tauri-apps/api/core';
import { emit } from '@tauri-apps/api/event';

const isTauri = typeof window !== 'undefined' && window.__TAURI__ !== undefined;

interface Settings {
  soundEnabled: boolean;
  volume: number;
  opacity: number;
  alwaysOnTop: boolean;
  defaultDuration: number;
  theme: 'dark' | 'light';
  notificationSound: string;
  customShortcut: {
    toggleVisibility: string;
    modifiers: string[];
    key: string;
  };
  watchFace: string;
}

interface SettingsStore extends Settings {
  isLoading: boolean;
  showSettings: boolean;
  
  loadSettings: () => Promise<void>;
  updateSettings: (updates: Partial<Settings>) => Promise<void>;
  toggleSettings: () => void;
}

const defaultSettings: Settings = {
  soundEnabled: true,
  volume: 0.5,
  opacity: 0.95,
  alwaysOnTop: true,
  defaultDuration: 25 * 60,
  theme: 'dark',
  notificationSound: 'default',
  customShortcut: {
    toggleVisibility: 'Hyperkey+P',
    modifiers: ['Super', 'Control', 'Alt', 'Shift'],
    key: 'P',
  },
  watchFace: 'default',
};

export const useSettingsStore = create<SettingsStore>((set, get) => ({
  ...defaultSettings,
  isLoading: true,
  showSettings: false,
  
  loadSettings: async () => {
    if (!isTauri) {
      set({ isLoading: false });
      return;
    }
    
    try {
      const rustSettings = await invoke<any>('load_settings');
      const settings = {
        soundEnabled: rustSettings.sound_enabled,
        volume: rustSettings.volume,
        opacity: rustSettings.opacity,
        alwaysOnTop: rustSettings.always_on_top,
        defaultDuration: rustSettings.default_duration,
        theme: rustSettings.theme,
        notificationSound: rustSettings.notification_sound,
        customShortcut: rustSettings.custom_shortcut,
        watchFace: rustSettings.watch_face,
      };
      set({ ...settings, isLoading: false });
    } catch (error) {
      console.error('Failed to load settings:', error);
      set({ isLoading: false });
    }
  },
  
  updateSettings: async (updates: Partial<Settings>) => {
    const currentSettings = get();
    
    // Apply updates to current settings
    const updatedSettings = { ...currentSettings, ...updates };
    
    // Convert to Rust format for saving
    const rustSettings = {
      sound_enabled: updatedSettings.soundEnabled,
      volume: updatedSettings.volume,
      opacity: updatedSettings.opacity,
      always_on_top: updatedSettings.alwaysOnTop,
      default_duration: updatedSettings.defaultDuration,
      theme: updatedSettings.theme,
      notification_sound: updatedSettings.notificationSound,
      custom_shortcut: updatedSettings.customShortcut,
      watch_face: updatedSettings.watchFace,
    };
    
    try {
      if (isTauri) {
        await invoke('save_settings', { settings: rustSettings });
      }
      set(updates);
      
      // Apply window settings immediately
      if (isTauri) {
        if ('opacity' in updates) {
          await invoke('set_window_opacity', { opacity: updates.opacity });
        }
        if ('alwaysOnTop' in updates) {
          await invoke('set_always_on_top', { alwaysOnTop: updates.alwaysOnTop });
        }
        
        // Emit settings changed event for other windows
        await emit('settings-changed', updates);
      }
    } catch (error) {
      console.error('Failed to save settings:', error);
    }
  },
  
  toggleSettings: () => {
    set((state) => ({ showSettings: !state.showSettings }));
  },
}));