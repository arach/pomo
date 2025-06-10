import { create } from 'zustand';
import { invoke } from '@tauri-apps/api/core';

interface TimerState {
  duration: number;
  remaining: number;
  isRunning: boolean;
  isPaused: boolean;
  
  setDuration: (duration: number) => Promise<void>;
  start: () => Promise<void>;
  pause: () => Promise<void>;
  stop: () => Promise<void>;
  updateState: (state: Partial<TimerState>) => void;
}

export const useTimerStore = create<TimerState>((set) => ({
  duration: 25 * 60,
  remaining: 25 * 60,
  isRunning: false,
  isPaused: false,
  
  setDuration: async (duration: number) => {
    await invoke('set_duration', { duration });
    set({ duration, remaining: duration });
  },
  
  start: async () => {
    await invoke('start_timer');
    set({ isRunning: true, isPaused: false });
  },
  
  pause: async () => {
    await invoke('pause_timer');
    set({ isPaused: true });
  },
  
  stop: async () => {
    await invoke('stop_timer');
    set((state) => ({ 
      isRunning: false, 
      isPaused: false, 
      remaining: state.duration 
    }));
  },
  
  updateState: (newState: Partial<TimerState>) => {
    set(newState);
  },
}));