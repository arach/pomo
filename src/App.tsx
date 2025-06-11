import { useEffect, useState, useCallback } from "react";
import { listen } from "@tauri-apps/api/event";
import { invoke } from "@tauri-apps/api/core";
import { WindowWrapper } from "./components/WindowWrapper";
import { CustomTitleBar } from "./components/CustomTitleBar";
import { TimerDisplay } from "./components/TimerDisplay";
import { DurationInput } from "./components/DurationInput";
import { StatusFooter } from "./components/StatusFooter";
import { useTimerStore, SessionType } from "./stores/timer-store";
import { useSettingsStore } from "./stores/settings-store";
import { AudioService } from "./services/audio";
import { WatchFaceLoader } from "./services/watchface-loader";

interface TimerUpdate {
  duration: number;
  remaining: number;
  is_running: boolean;
  is_paused: boolean;
}

function App() {
  const [isCollapsed, setIsCollapsed] = useState(false);
  const [showDurationInput, setShowDurationInput] = useState(false);
  const [currentWatchFaceConfig, setCurrentWatchFaceConfig] = useState<any>(null);
  const { duration, remaining, isRunning, isPaused, updateState, start, pause, stop, reset, setDuration } = useTimerStore((state) => ({
    duration: state.duration,
    remaining: state.remaining,
    isRunning: state.isRunning,
    isPaused: state.isPaused,
    updateState: state.updateState,
    start: state.start,
    pause: state.pause,
    stop: state.stop,
    reset: state.reset,
    setDuration: state.setDuration
  }));
  const { soundEnabled, volume, loadSettings, watchFace, updateSettings } = useSettingsStore();
  
  useEffect(() => {
    // Listen for timer updates
    const unlistenTimer = listen<TimerUpdate>('timer-update', (event) => {
      updateState({
        duration: event.payload.duration,
        remaining: event.payload.remaining,
        isRunning: event.payload.is_running,
        isPaused: event.payload.is_paused,
      });
      
      // Show duration input again when timer is stopped
      if (!event.payload.is_running) {
        setShowDurationInput(true);
      }
    });
    
    // Listen for timer completion
    const unlistenComplete = listen('timer-complete', async () => {
      // Play completion sound using our audio service
      if (soundEnabled) {
        AudioService.playCompletionSound(volume);
      }
    });
    
    // Listen for window collapse events
    const unlistenCollapse = listen<boolean>('window-collapsed', (event) => {
      setIsCollapsed(event.payload);
    });
    
    // Listen for visibility toggle
    const unlistenVisibility = listen('toggle-visibility', async () => {
      await invoke('toggle_visibility');
    });
    
    // Listen for settings changes (from settings window)
    const unlistenSettings = listen('settings-changed', async () => {
      await loadSettings();
    });
    
    // Load initial timer state
    invoke<TimerUpdate>('get_timer_state').then((state) => {
      updateState({
        duration: state.duration,
        remaining: state.remaining,
        isRunning: state.is_running,
        isPaused: state.is_paused,
      });
    });
    
    // Load initial settings
    loadSettings();
    
    return () => {
      unlistenTimer.then((fn) => fn());
      unlistenComplete.then((fn) => fn());
      unlistenCollapse.then((fn) => fn());
      unlistenVisibility.then((fn) => fn());
      unlistenSettings.then((fn) => fn());
    };
  }, [updateState, soundEnabled, volume, loadSettings]);
  
  // Load watch face config
  useEffect(() => {
    WatchFaceLoader.loadBuiltInFaces().then(() => {
      const config = WatchFaceLoader.getWatchFace(watchFace);
      setCurrentWatchFaceConfig(config);
    });
  }, [watchFace]);
  
  // Keyboard shortcuts handler
  const handleKeyPress = useCallback((e: KeyboardEvent) => {
    // Don't handle shortcuts if user is typing in an input
    if (e.target instanceof HTMLInputElement || e.target instanceof HTMLTextAreaElement) {
      return;
    }
    
    // Check for meta key (Cmd on Mac)
    const isCmd = e.metaKey || e.ctrlKey;
    
    // Show shortcuts window
    if (e.key === '?') {
      e.preventDefault();
      invoke('open_shortcuts_window');
      return;
    }
    
    // Settings (Cmd+,)
    if (isCmd && e.key === ',') {
      e.preventDefault();
      invoke('open_settings_window');
      return;
    }
    
    switch (e.key.toLowerCase()) {
      // Start timer
      case 's':
        if (!isRunning) {
          e.preventDefault();
          start();
          setShowDurationInput(false);
        }
        break;
        
      // Pause/Resume with space
      case ' ':
        e.preventDefault();
        if (isRunning) {
          if (isPaused) {
            start();
          } else {
            pause();
          }
        }
        break;
        
      // Reset timer
      case 'r':
        e.preventDefault();
        reset();
        setShowDurationInput(true);
        break;
        
      // Stop timer (Escape)
      case 'escape':
        if (isRunning) {
          e.preventDefault();
          stop();
          setShowDurationInput(true);
        }
        break;
        
      // Hide/Show window
      case 'h':
        e.preventDefault();
        invoke('toggle_visibility');
        break;
        
      // Toggle mute
      case 'm':
        e.preventDefault();
        updateSettings({ soundEnabled: !soundEnabled });
        break;
        
      // Quick duration set (1-9 for 5-45 minutes)
      case '1': case '2': case '3': case '4': case '5': 
      case '6': case '7': case '8': case '9':
        if (!isRunning) {
          e.preventDefault();
          const minutes = parseInt(e.key) * 5;
          setDuration(minutes * 60);
        }
        break;
        
      // Adjust duration with arrow keys
      case 'arrowup':
        if (!isRunning) {
          e.preventDefault();
          const increment = e.shiftKey ? 5 : 1;
          const newDuration = Math.min(duration + increment * 60, 99 * 60);
          setDuration(newDuration);
        }
        break;
        
      case 'arrowdown':
        if (!isRunning) {
          e.preventDefault();
          const decrement = e.shiftKey ? 5 : 1;
          const newDuration = Math.max(duration - decrement * 60, 60);
          setDuration(newDuration);
        }
        break;
        
      // Cycle through themes
      case 't':
        e.preventDefault();
        const themes = ['terminal', 'minimal', 'neon', 'rolodex'];
        const currentIndex = themes.indexOf(watchFace);
        const nextIndex = (currentIndex + 1) % themes.length;
        updateSettings({ watchFace: themes[nextIndex] });
        break;
        
      // Cycle through session types
      case 'c':
        if (!isRunning) {
          e.preventDefault();
          const { sessionType, setSessionType } = useTimerStore.getState();
          const types: SessionType[] = ['focus', 'break', 'planning', 'review', 'learning'];
          const currentIdx = types.indexOf(sessionType);
          const nextIdx = (currentIdx + 1) % types.length;
          setSessionType(types[nextIdx]);
        }
        break;
        
      // Open duration input panel
      case 'd':
        if (!isRunning) {
          e.preventDefault();
          setShowDurationInput(true);
        }
        break;
    }
  }, [isRunning, isPaused, start, pause, stop, reset, duration, setDuration, soundEnabled, updateSettings, watchFace]);
  
  // Add keyboard event listener
  useEffect(() => {
    window.addEventListener('keydown', handleKeyPress);
    return () => window.removeEventListener('keydown', handleKeyPress);
  }, [handleKeyPress]);
  
  const progress = duration > 0 ? ((duration - remaining) / duration) * 100 : 0;
  
  // Get progress bar style from watchface config
  const progressBarConfig = currentWatchFaceConfig?.progressBar || {
    height: '1px',
    background: 'rgba(255, 255, 255, 0.1)',
    color: 'rgba(255, 255, 255, 0.5)',
    glow: 'rgba(255, 255, 255, 0.3)'
  };

  return (
    <WindowWrapper>
      <CustomTitleBar isCollapsed={isCollapsed} />
      {progressBarConfig.hidden !== true && (
        <div 
          className="absolute top-7 left-0 right-0 z-40"
          style={{
            height: progressBarConfig.height,
            backgroundColor: progressBarConfig.background
          }}
        >
          <div 
            className="h-full transition-all duration-500 ease-out"
            style={{ 
              width: `${progress}%`,
              background: progressBarConfig.gradient || progressBarConfig.color,
              boxShadow: progress > 0 && progressBarConfig.glow ? `0 0 3px ${progressBarConfig.glow}` : 'none'
            }}
          />
        </div>
      )}
      <div className="flex-1 flex flex-col min-h-0">
        <TimerDisplay 
          isCollapsed={isCollapsed} 
          onTimeClick={() => !isRunning && setShowDurationInput(true)}
          showDurationInput={showDurationInput}
        />
      </div>
      {!isCollapsed && <StatusFooter />}
      {!isCollapsed && !isRunning && showDurationInput && (
        <div className="absolute inset-x-0 bottom-0 z-50">
          <DurationInput onDismiss={() => setShowDurationInput(false)} />
        </div>
      )}
    </WindowWrapper>
  );
}

export default App;