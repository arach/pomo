import { create } from 'zustand';
import { invoke } from '@tauri-apps/api/core';

interface Settings {
  soundEnabled: boolean;
  volume: number;
  opacity: number;
  alwaysOnTop: boolean;
  defaultDuration: number;
  theme: 'dark' | 'light';
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
};

export const useSettingsStore = create<SettingsStore>((set, get) => ({
  ...defaultSettings,
  isLoading: true,
  showSettings: false,
  
  loadSettings: async () => {
    try {
      const settings = await invoke<Settings>('load_settings');
      set({ ...settings, isLoading: false });
    } catch (error) {
      console.error('Failed to load settings:', error);
      set({ isLoading: false });
    }
  },
  
  updateSettings: async (updates: Partial<Settings>) => {
    const currentSettings = get();
    const newSettings = {
      soundEnabled: currentSettings.soundEnabled,
      volume: currentSettings.volume,
      opacity: currentSettings.opacity,
      alwaysOnTop: currentSettings.alwaysOnTop,
      defaultDuration: currentSettings.defaultDuration,
      theme: currentSettings.theme,
      ...updates,
    };
    
    try {
      await invoke('save_settings', { settings: newSettings });
      set(updates);
      
      // Apply window settings immediately
      if ('opacity' in updates) {
        await invoke('set_window_opacity', { opacity: updates.opacity });
      }
      if ('alwaysOnTop' in updates) {
        await invoke('set_always_on_top', { alwaysOnTop: updates.alwaysOnTop });
      }
    } catch (error) {
      console.error('Failed to save settings:', error);
    }
  },
  
  toggleSettings: () => {
    set((state) => ({ showSettings: !state.showSettings }));
  },
}));