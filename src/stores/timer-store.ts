import { create } from 'zustand';
import { invoke } from '@tauri-apps/api/core';

const isTauri = typeof window !== 'undefined' && window.__TAURI__ !== undefined;

// Browser timer simulation
let browserTimer: NodeJS.Timeout | null = null;

export type SessionType = 'focus' | 'break' | 'planning' | 'review' | 'learning';

interface TimerState {
  duration: number;
  remaining: number;
  isRunning: boolean;
  isPaused: boolean;
  sessionType: SessionType;
  
  setDuration: (duration: number) => Promise<void>;
  start: () => Promise<void>;
  pause: () => Promise<void>;
  stop: () => Promise<void>;
  reset: () => Promise<void>;
  updateState: (state: Partial<TimerState>) => void;
  setSessionType: (type: SessionType) => void;
}

export const useTimerStore = create<TimerState>((set) => ({
  duration: 25 * 60,
  remaining: 25 * 60,
  isRunning: false,
  isPaused: false,
  sessionType: 'focus',
  
  setDuration: async (duration: number) => {
    if (isTauri) {
      await invoke('set_duration', { duration });
    }
    set({ duration, remaining: duration });
  },
  
  start: async () => {
    if (isTauri) {
      await invoke('start_timer');
    } else {
      // Browser simulation
      if (browserTimer) {
        clearInterval(browserTimer);
      }
      browserTimer = setInterval(() => {
        const state = useTimerStore.getState();
        if (state.remaining > 0 && state.isRunning && !state.isPaused) {
          state.updateState({ remaining: state.remaining - 1 });
          if (state.remaining === 0) {
            state.stop();
          }
        }
      }, 1000);
    }
    set({ isRunning: true, isPaused: false });
  },
  
  pause: async () => {
    if (isTauri) {
      await invoke('pause_timer');
    }
    set({ isPaused: true });
  },
  
  stop: async () => {
    if (isTauri) {
      await invoke('stop_timer');
    } else if (browserTimer) {
      clearInterval(browserTimer);
      browserTimer = null;
    }
    set((state) => ({ 
      isRunning: false, 
      isPaused: false, 
      remaining: state.duration 
    }));
  },
  
  reset: async () => {
    if (isTauri) {
      await invoke('stop_timer');
    } else if (browserTimer) {
      clearInterval(browserTimer);
      browserTimer = null;
    }
    set((state) => ({ 
      isRunning: false, 
      isPaused: false, 
      remaining: state.duration 
    }));
  },
  
  updateState: (newState: Partial<TimerState>) => {
    set(newState);
  },
  
  setSessionType: (type: SessionType) => {
    set({ sessionType: type });
  },
}));