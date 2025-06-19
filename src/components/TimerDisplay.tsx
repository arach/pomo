import { Play, Pause, Square, MoreHorizontal } from 'lucide-react';
import { useTimerStore } from '../stores/timer-store';
import { useSettingsStore } from '../stores/settings-store';
import { useEffect, useState } from 'react';
import { WatchFaceRenderer } from './watchface/WatchFaceRenderer';
import { WatchFaceLoader } from '../services/watchface-loader';
import { invoke } from '@tauri-apps/api/core';

interface TimerDisplayProps {
  isCollapsed?: boolean;
  onTimeClick?: () => void;
  showDurationInput?: boolean;
  version?: string;
}

export function TimerDisplay({ isCollapsed = false, onTimeClick, showDurationInput = false, version = 'v1' }: TimerDisplayProps) {
  if (import.meta.env.DEV) {
    console.log(`TimerDisplay: version prop = ${version}`);
  }
  const { duration, remaining, isRunning, isPaused, start, pause, stop, reset } = useTimerStore();
  const { watchFace: settingsWatchFace } = useSettingsStore();
  const [currentWatchFaceConfig, setCurrentWatchFaceConfig] = useState<any>(null);
  const [showHint, setShowHint] = useState(false);
  
  // Check URL params for watchface override
  const urlParams = new URLSearchParams(window.location.search);
  const urlWatchFace = urlParams.get('watchface');
  const watchFace = urlWatchFace || settingsWatchFace;
  
  const openSettings = async () => {
    try {
      await invoke('open_settings_window');
    } catch (error) {
      console.error('Failed to open settings window:', error);
    }
  };
  
  useEffect(() => {
    // Load watch faces and get current config
    WatchFaceLoader.loadBuiltInFaces().then(() => {
      const config = WatchFaceLoader.getWatchFace(watchFace);
      if (config) {
        setCurrentWatchFaceConfig(config);
      } else {
        console.warn(`Watchface '${watchFace}' not found, using default`);
        const defaultConfig = WatchFaceLoader.getWatchFace('default');
        setCurrentWatchFaceConfig(defaultConfig);
      }
    });
  }, [watchFace]);
  
  const formatTime = (seconds: number) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  };
  
  if (isCollapsed) {
    // Get theme colors from current watchface
    const themeColors = currentWatchFaceConfig?.theme?.colors || {};
    const fontFamily = currentWatchFaceConfig?.theme?.fonts?.primary || 'font-mono';
    
    return (
      <div className="flex items-center justify-between px-3 py-1">
        <span 
          className="text-lg tabular-nums"
          style={{
            fontFamily: fontFamily,
            color: themeColors.foreground || 'inherit'
          }}
        >
          {formatTime(remaining)}
        </span>
        <div className="flex gap-1">
          {!isRunning || isPaused ? (
            <button
              onClick={start}
              className="p-1.5 hover:bg-white/10 rounded-lg transition-all duration-200 hover:scale-110"
              aria-label="Start"
              style={{ color: themeColors.accent || 'inherit' }}
              data-tauri-drag-region="false"
            >
              <Play className="w-4 h-4" />
            </button>
          ) : (
            <button
              onClick={pause}
              className="p-1.5 hover:bg-white/10 rounded-lg transition-all duration-200 hover:scale-110"
              aria-label="Pause"
              style={{ color: themeColors.accent || 'inherit' }}
              data-tauri-drag-region="false"
            >
              <Pause className="w-4 h-4" />
            </button>
          )}
          <button
            onClick={stop}
            className="p-1.5 hover:bg-white/10 rounded-lg transition-all duration-200 hover:scale-110"
            aria-label="Stop"
            style={{ color: themeColors.accent || 'inherit' }}
            data-tauri-drag-region="false"
          >
            <Square className="w-4 h-4" />
          </button>
        </div>
      </div>
    );
  }
  
  return (
    <div className="flex-1 flex flex-col items-center justify-center relative z-10">
      {/* Settings button with gradual discovery */}
      <button
        className="absolute top-2 right-2 p-1.5 opacity-20 hover:opacity-80 transition-opacity duration-300 z-50 hover:bg-white/10 rounded-lg"
        onClick={openSettings}
        onMouseEnter={() => setShowHint(true)}
        onMouseLeave={() => setShowHint(false)}
        aria-label="Settings"
        data-tauri-drag-region="false"
      >
        <MoreHorizontal className="w-4 h-4" />
        {showHint && (
          <div className="absolute top-full right-0 mt-1 px-2 py-1 bg-black/80 text-white text-xs whitespace-nowrap rounded">
            Settings
          </div>
        )}
      </button>
      
      {/* Watch Face */}
      <div className="flex items-center justify-center w-full flex-1">
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
            onTimeClick={onTimeClick}
            hideControls={showDurationInput}
            version={version}
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