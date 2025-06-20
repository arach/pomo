import { create } from 'zustand';
import { invoke } from '@tauri-apps/api/core';



export type SessionType = 'focus' | 'break' | 'planning' | 'review' | 'learning';

interface TimerState {
  duration: number;
  remaining: number;
  isRunning: boolean;
  isPaused: boolean;
  sessionType: SessionType;
  sessionName: string | null;
  currentSessionId: string | null;
  pauseCount: number;
  pauseStartTime: number | null;
  totalPauseTime: number;
  
  setDuration: (duration: number) => Promise<void>;
  start: () => Promise<void>;
  pause: () => Promise<void>;
  stop: () => Promise<void>;
  reset: () => Promise<void>;
  updateState: (state: Partial<TimerState>) => void;
  setSessionType: (type: SessionType) => void;
  setSessionName: (name: string | null) => Promise<void>;
}

export const useTimerStore = create<TimerState>((set, get) => ({
  duration: 25 * 60,
  remaining: 25 * 60,
  isRunning: false,
  isPaused: false,
  sessionType: 'focus',
  sessionName: null,
  currentSessionId: null,
  pauseCount: 0,
  pauseStartTime: null,
  totalPauseTime: 0,
  
  setDuration: async (duration: number) => {
    try {
      await invoke('set_duration', { duration });
    } catch (error) {
      console.error('Failed to set duration:', error);
    }
    set({ duration, remaining: duration });
  },
  
  start: async () => {
    const state = get();
    
    try {
      // If not currently running, start a new session record
      if (!state.isRunning && !state.currentSessionId) {
        const sessionId = await invoke<string>('start_session_record', { 
          sessionType: state.sessionType 
        });
        set({ 
          currentSessionId: sessionId,
          pauseCount: 0,
          totalPauseTime: 0,
          pauseStartTime: null
        });
      }
      
      // If resuming from pause, calculate pause duration
      if (state.isPaused && state.pauseStartTime) {
        const pauseDuration = Date.now() - state.pauseStartTime;
        set(state => ({ 
          totalPauseTime: state.totalPauseTime + pauseDuration,
          pauseStartTime: null
        }));
      }
      
      await invoke('start_timer');
      set({ isRunning: true, isPaused: false });
    } catch (error) {
      console.error('Failed to start timer:', error);
    }
  },
  
  pause: async () => {
    try {
      await invoke('pause_timer');
      set(state => ({ 
        isPaused: true,
        pauseStartTime: Date.now(),
        pauseCount: state.pauseCount + 1
      }));
    } catch (error) {
      console.error('Failed to pause timer:', error);
    }
  },
  
  stop: async () => {
    const state = get();
    
    try {
      await invoke('stop_timer');
      
      // Complete session record if we have one
      if (state.currentSessionId) {
        const actualDuration = state.duration - state.remaining;
        let totalPauseTime = state.totalPauseTime;
        
        // If currently paused, add current pause duration
        if (state.isPaused && state.pauseStartTime) {
          totalPauseTime += Date.now() - state.pauseStartTime;
        }
        
        await invoke('complete_session_record', {
          sessionId: state.currentSessionId,
          completed: false, // Stop means interrupted
          actualDuration: Math.floor(actualDuration),
          pauseCount: state.pauseCount,
          pauseDuration: Math.floor(totalPauseTime / 1000) // Convert to seconds
        });
      }
    } catch (error) {
      console.error('Failed to stop timer:', error);
    }
    
    set((state) => ({ 
      isRunning: false, 
      isPaused: false, 
      remaining: state.duration,
      currentSessionId: null,
      pauseCount: 0,
      totalPauseTime: 0,
      pauseStartTime: null
    }));
  },
  
  reset: async () => {
    const state = get();
    
    try {
      await invoke('stop_timer');
      
      // Complete session record as interrupted if we have one
      if (state.currentSessionId) {
        const actualDuration = state.duration - state.remaining;
        let totalPauseTime = state.totalPauseTime;
        
        // If currently paused, add current pause duration
        if (state.isPaused && state.pauseStartTime) {
          totalPauseTime += Date.now() - state.pauseStartTime;
        }
        
        await invoke('complete_session_record', {
          sessionId: state.currentSessionId,
          completed: false, // Reset means interrupted
          actualDuration: Math.floor(actualDuration),
          pauseCount: state.pauseCount,
          pauseDuration: Math.floor(totalPauseTime / 1000)
        });
      }
    } catch (error) {
      console.error('Failed to reset timer:', error);
    }
    
    set((state) => ({ 
      isRunning: false, 
      isPaused: false, 
      remaining: state.duration,
      currentSessionId: null,
      pauseCount: 0,
      totalPauseTime: 0,
      pauseStartTime: null
    }));
  },
  
  updateState: (newState: Partial<TimerState>) => {
    set(newState);
  },
  
  setSessionType: (type: SessionType) => {
    set({ sessionType: type });
  },
  
  setSessionName: async (name: string | null) => {
    try {
      await invoke('set_session_name', { name });
    } catch (error) {
      console.error('Failed to set session name:', error);
    }
    set({ sessionName: name });
  },
}));