import { Settings, Play, Pause, Square } from 'lucide-react';
import { useTimerStore } from '../stores/timer-store';
import { useSettingsStore } from '../stores/settings-store';
import { useEffect, useState } from 'react';
import { WatchFaceRenderer } from './watchface/WatchFaceRenderer';
import { WatchFaceLoader } from '../services/watchface-loader';
import { invoke } from '@tauri-apps/api/core';

interface TimerDisplayProps {
  isCollapsed?: boolean;
}

export function TimerDisplay({ isCollapsed = false }: TimerDisplayProps) {
  const { duration, remaining, isRunning, isPaused, start, pause, stop, reset } = useTimerStore();
  const { watchFace } = useSettingsStore();
  const [currentWatchFaceConfig, setCurrentWatchFaceConfig] = useState<any>(null);
  
  const openSettings = async () => {
    await invoke('open_settings_window');
  };
  
  useEffect(() => {
    // Load watch faces and get current config
    WatchFaceLoader.loadBuiltInFaces().then(() => {
      const config = WatchFaceLoader.getWatchFace(watchFace);
      setCurrentWatchFaceConfig(config);
    });
  }, [watchFace]);
  
  const formatTime = (seconds: number) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  };
  
  if (isCollapsed) {
    return (
      <div className="flex items-center justify-between px-3 py-2">
        <span className="text-lg font-mono tabular-nums">{formatTime(remaining)}</span>
        <div className="flex gap-1">
          {!isRunning || isPaused ? (
            <button
              onClick={start}
              className="p-1.5 hover:bg-white/10 rounded-lg transition-all duration-200 hover:scale-110"
              aria-label="Start"
            >
              <Play className="w-4 h-4" />
            </button>
          ) : (
            <button
              onClick={pause}
              className="p-1.5 hover:bg-white/10 rounded-lg transition-all duration-200 hover:scale-110"
              aria-label="Pause"
            >
              <Pause className="w-4 h-4" />
            </button>
          )}
          <button
            onClick={stop}
            className="p-1.5 hover:bg-white/10 rounded-lg transition-all duration-200 hover:scale-110"
            aria-label="Stop"
          >
            <Square className="w-4 h-4" />
          </button>
        </div>
      </div>
    );
  }
  
  return (
    <div className="flex-1 flex flex-col items-center justify-center relative py-2">
      {/* Settings button */}
      <button
        onClick={openSettings}
        className="absolute top-1 right-1 p-1 hover:bg-white/10 rounded-lg transition-all duration-200 hover:rotate-90 z-20"
        aria-label="Settings"
      >
        <Settings className="w-4 h-4 text-muted-foreground" />
      </button>
      
      {/* Watch Face */}
      <div className="flex items-center justify-center w-full h-full">
        {currentWatchFaceConfig ? (
          <WatchFaceRenderer
            config={currentWatchFaceConfig}
            duration={duration}
            remaining={remaining}
            progress={duration > 0 ? ((duration - remaining) / duration) * 100 : 0}
            isRunning={isRunning}
            isPaused={isPaused}
            onStart={start}
            onPause={pause}
            onStop={stop}
            onReset={reset}
          />
        ) : (
          // Fallback while loading
          <div className="w-24 h-24 flex items-center justify-center">
            <span className="text-2xl font-mono tabular-nums">{formatTime(remaining)}</span>
          </div>
        )}
      </div>
    </div>
  );
}