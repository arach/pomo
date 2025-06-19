import { create } from 'zustand';
import { invoke } from '@tauri-apps/api/core';



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
    try {
      await invoke('set_duration', { duration });
    } catch (error) {
      console.error('Failed to set duration:', error);
    }
    set({ duration, remaining: duration });
  },
  
  start: async () => {
    try {
      await invoke('start_timer');
    } catch (error) {
      console.error('Failed to start timer:', error);
    }
    set({ isRunning: true, isPaused: false });
  },
  
  pause: async () => {
    try {
      await invoke('pause_timer');
    } catch (error) {
      console.error('Failed to pause timer:', error);
    }
    set({ isPaused: true });
  },
  
  stop: async () => {
    try {
      await invoke('stop_timer');
    } catch (error) {
      console.error('Failed to stop timer:', error);
    }
    set((state) => ({ 
      isRunning: false, 
      isPaused: false, 
      remaining: state.duration 
    }));
  },
  
  reset: async () => {
    try {
      await invoke('stop_timer');
    } catch (error) {
      console.error('Failed to reset timer:', error);
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