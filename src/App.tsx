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
import { SplitViewComparison } from "./components/dev/SplitViewComparison";
import { SessionNameInput } from "./components/SessionNameInput";
import { SessionCompleteModal } from "./components/SessionCompleteModal";

interface TimerUpdate {
  duration: number;
  remaining: number;
  is_running: boolean;
  is_paused: boolean;
  session_name: string | null;
}

function App() {
  const [isCollapsed, setIsCollapsed] = useState(false);
  const [showDurationInput, setShowDurationInput] = useState(false);
  const [showSessionNameInput, setShowSessionNameInput] = useState(false);
  const [currentWatchFaceConfig, setCurrentWatchFaceConfig] = useState<any>(null);
  const [showCompleteModal, setShowCompleteModal] = useState(false);
  const [completedSession, setCompletedSession] = useState<any>(null);
  const [showCompletionPulse, setShowCompletionPulse] = useState(false);
  
  // Development mode version support
  const urlParams = new URLSearchParams(window.location.search);
  const version = urlParams.get('version') || 'v1';
  const splitView = urlParams.get('split') === 'true';
  const isDev = import.meta.env.DEV;
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
        sessionName: event.payload.session_name,
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
      
      // Complete the session record
      const { currentSessionId, duration, pauseCount, totalPauseTime, pauseStartTime, sessionType, sessionName } = useTimerStore.getState();
      
      // Show completion modal with session info
      setCompletedSession({
        duration,
        sessionType,
        name: sessionName,
        pauseCount
      });
      
      // If collapsed, expand the window first
      if (isCollapsed) {
        await invoke('toggle_collapse');
        // Small delay to ensure window expands before showing animations
        await new Promise(resolve => setTimeout(resolve, 100));
      }
      
      // Trigger completion pulse animation
      setShowCompletionPulse(true);
      setTimeout(() => setShowCompletionPulse(false), 2000);
      
      // Show modal after a short delay to let the pulse animation play
      setTimeout(() => setShowCompleteModal(true), 500);
      
      if (currentSessionId) {
        try {
          let finalPauseTime = totalPauseTime;
          // If currently paused when timer completes, add current pause duration
          if (pauseStartTime) {
            finalPauseTime += Date.now() - pauseStartTime;
          }
          
          await invoke('complete_session_record', {
            sessionId: currentSessionId,
            completed: true, // Timer completed naturally
            actualDuration: duration, // Full duration completed
            pauseCount,
            pauseDuration: Math.floor(finalPauseTime / 1000)
          });
          
          // Clear session tracking state
          useTimerStore.setState({
            currentSessionId: null,
            pauseCount: 0,
            totalPauseTime: 0,
            pauseStartTime: null
          });
        } catch (error) {
          console.error('Failed to complete session record:', error);
        }
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
        sessionName: state.session_name,
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
        if (isRunning) {
          e.preventDefault();
          if (isPaused) {
            start();
          } else {
            pause();
          }
        }
        break;
        
      // Reset timer
      case 'r':
        if (!isRunning) {
          e.preventDefault();
          reset();
          setShowDurationInput(true);
        }
        break;
        
      // Stop timer (Escape)
      case 'escape':
        if (isRunning) {
          e.preventDefault();
          stop();
          setShowDurationInput(true);
        }
        break;
        
      // Toggle mute
      case 'm':
        if (!isRunning) {
          e.preventDefault();
          updateSettings({ soundEnabled: !soundEnabled });
        }
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
        if (!isRunning) {
          e.preventDefault();
          const themes = ['default', 'terminal', 'rolodex', 'neon', 'retro-digital', 'retro-lcd'];
          const currentIndex = themes.indexOf(watchFace);
          const nextIndex = (currentIndex + 1) % themes.length;
          updateSettings({ watchFace: themes[nextIndex] });
        }
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
        
      // Open session name input panel
      case 'n':
        if (!isRunning) {
          e.preventDefault();
          setShowSessionNameInput(true);
        }
        break;
    }
  }, [isRunning, isPaused, start, pause, stop, reset, duration, setDuration, soundEnabled, updateSettings, watchFace]);
  
  // Add keyboard event listener
  useEffect(() => {
    window.addEventListener('keydown', handleKeyPress);
    
    // Ensure the window is focusable
    // Make sure the window can receive focus
    document.body.setAttribute('tabindex', '0');
    document.body.focus();
    
    return () => {
      window.removeEventListener('keydown', handleKeyPress);
    };
  }, [handleKeyPress]);
  
  const progress = duration > 0 ? ((duration - remaining) / duration) * 100 : 0;
  
  // Get progress bar style from watchface config
  const progressBarConfig = currentWatchFaceConfig?.progressBar || {
    height: '1px',
    background: 'rgba(255, 255, 255, 0.1)',
    color: 'rgba(255, 255, 255, 0.5)',
    glow: 'rgba(255, 255, 255, 0.3)'
  };
  
  // Development mode split view
  if (isDev && splitView) {
    return <SplitViewComparison />;
  }

  return (
    <WindowWrapper>
      <CustomTitleBar isCollapsed={isCollapsed} />
      
      {/* Completion pulse animation */}
      {showCompletionPulse && (
        <div className="absolute inset-0 pointer-events-none z-50">
          <div className="absolute inset-0 bg-green-500 animate-ping opacity-20 rounded-lg" />
          <div className="absolute inset-0 flex items-center justify-center">
            <div className="w-32 h-32 bg-green-500 rounded-full animate-ping opacity-30" />
          </div>
        </div>
      )}
      
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
      <div className="flex-1 flex flex-col min-h-0 relative">
        {/* Draggable background area */}
        {!isCollapsed && (
          <div 
            className="absolute inset-0 z-0" 
            data-tauri-drag-region
          />
        )}
        <TimerDisplay 
          isCollapsed={isCollapsed} 
          onTimeClick={() => !isRunning && setShowDurationInput(true)}
          showDurationInput={showDurationInput}
          version={version}
        />
      </div>
      {!isCollapsed && <StatusFooter />}
      {!isCollapsed && !isRunning && showDurationInput && (
        <div className="absolute inset-x-0 bottom-0 z-50">
          <DurationInput onDismiss={() => setShowDurationInput(false)} />
        </div>
      )}
      {showSessionNameInput && (
        <SessionNameInput onDismiss={() => setShowSessionNameInput(false)} />
      )}
      {completedSession && (
        <SessionCompleteModal
          isOpen={showCompleteModal}
          onClose={() => setShowCompleteModal(false)}
          session={completedSession}
        />
      )}
    </WindowWrapper>
  );
}

export default App;