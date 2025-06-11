import { useTimerStore } from '../stores/timer-store';
import { useSettingsStore } from '../stores/settings-store';

export function StatusFooter() {
  const { isRunning, isPaused, remaining } = useTimerStore();
  const { watchFace } = useSettingsStore();
  
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
      <div className="ml-auto text-muted-foreground/70">
        {getStatus()}
      </div>
    </div>
  );
}