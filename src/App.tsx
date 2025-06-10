import { useEffect, useState } from "react";
import { listen } from "@tauri-apps/api/event";
import { invoke } from "@tauri-apps/api/core";
import { WindowWrapper } from "./components/WindowWrapper";
import { CustomTitleBar } from "./components/CustomTitleBar";
import { TimerDisplay } from "./components/TimerDisplay";
import { DurationInput } from "./components/DurationInput";
import { SettingsPanel } from "./components/SettingsPanel";
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
  const updateState = useTimerStore((state) => state.updateState);
  const { soundEnabled, volume } = useSettingsStore();
  
  useEffect(() => {
    // Listen for timer updates
    const unlistenTimer = listen<TimerUpdate>('timer-update', (event) => {
      updateState({
        duration: event.payload.duration,
        remaining: event.payload.remaining,
        isRunning: event.payload.is_running,
        isPaused: event.payload.is_paused,
      });
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
    
    // Load initial timer state
    invoke<TimerUpdate>('get_timer_state').then((state) => {
      updateState({
        duration: state.duration,
        remaining: state.remaining,
        isRunning: state.is_running,
        isPaused: state.is_paused,
      });
    });
    
    return () => {
      unlistenTimer.then((fn) => fn());
      unlistenComplete.then((fn) => fn());
      unlistenCollapse.then((fn) => fn());
      unlistenVisibility.then((fn) => fn());
    };
  }, [updateState, soundEnabled, volume]);
  
  return (
    <WindowWrapper>
      <CustomTitleBar isCollapsed={isCollapsed} />
      <TimerDisplay isCollapsed={isCollapsed} />
      {!isCollapsed && <DurationInput />}
      <SettingsPanel />
    </WindowWrapper>
  );
}

export default App;