import { useEffect, useRef } from 'react';
import { AudioService } from '../services/audio';
import { useSettingsStore } from '../stores/settings-store';
import { useTimerStore } from '../stores/timer-store';

export function useAmbientSound(watchFaceConfig: any) {
  const { soundEnabled, volume } = useSettingsStore();
  const { isRunning, isPaused } = useTimerStore();
  const currentSoundType = useRef<string | null>(null);
  
  useEffect(() => {
    // Check if watchface has ambient sound configuration
    const ambientConfig = watchFaceConfig?.ambientSound;
    if (!ambientConfig?.enabled || !ambientConfig?.type) {
      AudioService.stopAmbientSound();
      currentSoundType.current = null;
      return;
    }
    
    // Only play ambient sound if:
    // 1. Sound is enabled in settings
    // 2. Timer is running and not paused
    // 3. Watchface has ambient sound configured
    const shouldPlayAmbient = soundEnabled && isRunning && !isPaused;
    
    if (shouldPlayAmbient) {
      if (currentSoundType.current !== ambientConfig.type) {
        // Stop any existing sound before starting new one
        AudioService.stopAmbientSound();
        // Small delay to ensure cleanup
        setTimeout(() => {
          AudioService.startAmbientSound(ambientConfig.type, volume * 0.3); // Ambient at 30% of main volume
          currentSoundType.current = ambientConfig.type;
        }, 100);
      }
    } else if (currentSoundType.current) {
      // Stop ambient sound
      AudioService.stopAmbientSound();
      currentSoundType.current = null;
    }
    
    // Cleanup on unmount
    return () => {
      AudioService.stopAmbientSound();
      currentSoundType.current = null;
    };
  }, [watchFaceConfig, soundEnabled, volume, isRunning, isPaused]);
}