import { useEffect, useState } from "react";
import { listen } from "@tauri-apps/api/event";
import { invoke } from "@tauri-apps/api/core";
import { WindowWrapper } from "./components/WindowWrapper";
import { CustomTitleBar } from "./components/CustomTitleBar";
import { TimerDisplay } from "./components/TimerDisplay";
import { DurationInput } from "./components/DurationInput";
import { StatusFooter } from "./components/StatusFooter";
import { useTimerStore } from "./stores/timer-store";
import { useSettingsStore } from "./stores/settings-store";
import { AudioService } from "./services/audio";

interface TimerUpdate {
  duration: number;
  remaining: number;
  is_running: boolean;
  is_paused: boolean;
}

function App() {
  const [isCollapsed, setIsCollapsed] = useState(false);
  const [showDurationInput, setShowDurationInput] = useState(true);
  const { duration, remaining, isRunning, updateState } = useTimerStore((state) => ({
    duration: state.duration,
    remaining: state.remaining,
    isRunning: state.isRunning,
    updateState: state.updateState
  }));
  const { soundEnabled, volume, loadSettings } = useSettingsStore();
  
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
  
  const progress = duration > 0 ? ((duration - remaining) / duration) * 100 : 0;

  return (
    <WindowWrapper>
      <CustomTitleBar isCollapsed={isCollapsed} />
      <div 
        className="absolute top-7 left-0 right-0 h-[2px] bg-black/20 z-40"
      >
        <div 
          className="h-full bg-green-500 transition-all duration-300"
          style={{ 
            width: `${progress}%`,
            boxShadow: progress > 0 ? '0 0 4px rgba(34, 197, 94, 0.5)' : 'none'
          }}
        />
      </div>
      <div className="flex-1 flex flex-col min-h-0">
        <TimerDisplay 
          isCollapsed={isCollapsed} 
          onTimeClick={() => !isRunning && setShowDurationInput(true)}
        />
        {!isCollapsed && !isRunning && showDurationInput && (
          <DurationInput onDismiss={() => setShowDurationInput(false)} />
        )}
      </div>
      {!isCollapsed && <StatusFooter />}
    </WindowWrapper>
  );
}

export default App;