/**
 * Mock implementation of @tauri-apps/api/core for web development
 */

// Simple in-memory state for web demo
let webTimerState = {
  duration: 25 * 60,
  remaining: 25 * 60,
  is_running: false,
  is_paused: false,
  session_name: null,
  current_session_id: null as string | null,
};

let webSettings = {
  soundEnabled: true,
  volume: 0.5,
  opacity: 0.95,
  alwaysOnTop: false,
  defaultDuration: 25 * 60,
  theme: 'dark',
  notificationSound: 'default',
  customShortcut: {
    toggleVisibility: 'CmdOrCtrl+Shift+P',
  },
  watchFace: 'default',
};

let webTimerInterval: NodeJS.Timeout | null = null;

// Event system for web
const eventListeners = new Map<string, Array<(data: any) => void>>();

function emitEvent(event: string, payload: any) {
  const listeners = eventListeners.get(event);
  if (listeners) {
    listeners.forEach(callback => {
      callback({ payload });
    });
  }
}

function startWebTimer() {
  if (webTimerInterval) clearInterval(webTimerInterval);
  
  webTimerInterval = setInterval(() => {
    if (!webTimerState.is_running || webTimerState.is_paused) {
      return;
    }
    
    if (webTimerState.remaining > 0) {
      webTimerState.remaining -= 1;
      emitEvent('timer-update', { ...webTimerState });
      
      if (webTimerState.remaining === 0) {
        webTimerState.is_running = false;
        emitEvent('timer-complete', {});
        clearInterval(webTimerInterval!);
        webTimerInterval = null;
      }
    }
  }, 1000);
}

export async function invoke(command: string, args?: any): Promise<any> {
  console.log(`[Web Mock] invoke: ${command}`, args);
  
  // Add small delay to simulate async behavior
  await new Promise(resolve => setTimeout(resolve, 10));
  
  switch (command) {
    case 'get_timer_state':
      return { ...webTimerState };
      
    case 'set_duration':
      webTimerState.duration = args.duration;
      webTimerState.remaining = args.duration;
      return;
      
    case 'start_timer':
      webTimerState.is_running = true;
      webTimerState.is_paused = false;
      startWebTimer();
      return;
      
    case 'pause_timer':
      webTimerState.is_paused = true;
      return;
      
    case 'stop_timer':
      webTimerState.is_running = false;
      webTimerState.is_paused = false;
      webTimerState.remaining = webTimerState.duration;
      if (webTimerInterval) {
        clearInterval(webTimerInterval);
        webTimerInterval = null;
      }
      return;
      
    case 'load_settings':
      const stored = localStorage.getItem('pomo-settings');
      return stored ? JSON.parse(stored) : { ...webSettings };
      
    case 'save_settings':
      webSettings = { ...webSettings, ...args };
      localStorage.setItem('pomo-settings', JSON.stringify(webSettings));
      return;
      
    case 'set_session_name':
      webTimerState.session_name = args.name;
      return;
      
    case 'start_session_record':
      const sessionId = `web-session-${Date.now()}`;
      webTimerState.current_session_id = sessionId;
      console.log('[Web Mock] Started session:', sessionId);
      return sessionId;
      
    case 'complete_session_record':
      console.log('[Web Mock] Session completed:', args);
      webTimerState.current_session_id = null;
      return;
      
    case 'get_session_stats':
      return {
        total_sessions: 0,
        completed_sessions: 0,
        completion_rate: 0,
        average_duration: 0,
        total_focus_time: 0,
        current_streak: 0,
        longest_streak: 0,
        named_sessions_completion_rate: 0,
        unnamed_sessions_completion_rate: 0,
      };
      
    case 'get_recent_sessions':
      return [];
      
    // Window/UI commands (no-ops for web)
    case 'toggle_collapse':
    case 'toggle_visibility':
    case 'open_settings_window':
    case 'open_shortcuts_window':
      console.log(`[Web Mock] UI command: ${command} (no-op)`);
      return;
      
    default:
      console.warn(`[Web Mock] Unhandled command: ${command}`);
      return;
  }
}

// Mock additional exports that Tauri plugins expect
export class Resource {
  constructor(public rid: number) {}
  
  async close() {
    console.log('[Web Mock] Resource.close()');
  }
}

export class Channel<T = any> {
  onmessage: ((message: T) => void) | null = null;
  
  constructor() {}
  
  close() {
    console.log('[Web Mock] Channel.close()');
  }
}

// For compatibility, also export the event emitter
export { emitEvent as __webEmitEvent, eventListeners as __webEventListeners };