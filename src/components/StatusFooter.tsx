import { useTimerStore } from '../stores/timer-store';
import { useSettingsStore } from '../stores/settings-store';
import { useEffect, useState } from 'react';
import { invoke } from '@tauri-apps/api/core';
import { listen } from '@tauri-apps/api/event';
import { formatDuration } from '../utils/format';

export function StatusFooter() {
  const { isRunning, isPaused, remaining } = useTimerStore();
  const { watchFace } = useSettingsStore();
  const [todayStats, setTodayStats] = useState({ sessions: 0, focusTime: 0 });
  
  useEffect(() => {
    // Load today's stats on mount and when timer completes
    const loadTodayStats = async () => {
      try {
        const count = await invoke<number>('get_todays_session_count');
        const stats = await invoke<any>('get_session_stats', { days: 1 });
        setTodayStats({
          sessions: count,
          focusTime: stats.totalFocusTime || 0
        });
      } catch (error) {
        console.error('Failed to load today stats:', error);
      }
    };
    
    loadTodayStats();
    
    // Listen for timer completion to update stats
    const unlisten = listen('timer-complete', loadTodayStats);
    
    return () => {
      unlisten.then(fn => fn());
    };
  }, []);
  
  const getStatus = () => {
    if (remaining <= 0 && !isRunning) return 'FINISHED';
    if (isPaused) return 'PAUSED';
    if (isRunning) return 'RUNNING';
    return 'READY';
  };

  // Only show for certain watchfaces that don't have their own status
  const watchFacesWithFooter = ['default', 'rolodex'];
  if (!watchFacesWithFooter.includes(watchFace)) {
    return null;
  }

  return (
    <div className="absolute bottom-0 left-0 right-0 h-6 bg-black/5 dark:bg-white/5 border-t border-border/20 flex items-center px-3 text-xs">
      <div className="flex items-center gap-3 text-muted-foreground/70">
        <span>Sessions: {todayStats.sessions}</span>
        <span className="text-muted-foreground/40">|</span>
        <span>Focus: {formatDuration(todayStats.focusTime)}</span>
      </div>
      <div className="ml-auto text-muted-foreground/70">
        {getStatus()}
      </div>
    </div>
  );
}