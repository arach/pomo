import { Play, Pause, Square, RotateCcw } from 'lucide-react';
import { useTimerStore } from '../stores/timer-store';

interface TimerDisplayProps {
  isCollapsed?: boolean;
}

export function TimerDisplay({ isCollapsed = false }: TimerDisplayProps) {
  const { duration, remaining, isRunning, isPaused, start, pause, stop } = useTimerStore();
  
  const formatTime = (seconds: number) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  };
  
  const progress = ((duration - remaining) / duration) * 100;
  
  if (isCollapsed) {
    return (
      <div className="flex items-center justify-between px-3 py-2">
        <span className="text-lg font-mono">{formatTime(remaining)}</span>
        <div className="flex gap-1">
          {!isRunning || isPaused ? (
            <button
              onClick={start}
              className="p-1 hover:bg-secondary rounded transition-colors"
              aria-label="Start"
            >
              <Play className="w-4 h-4" />
            </button>
          ) : (
            <button
              onClick={pause}
              className="p-1 hover:bg-secondary rounded transition-colors"
              aria-label="Pause"
            >
              <Pause className="w-4 h-4" />
            </button>
          )}
          <button
            onClick={stop}
            className="p-1 hover:bg-secondary rounded transition-colors"
            aria-label="Stop"
          >
            <Square className="w-4 h-4" />
          </button>
        </div>
      </div>
    );
  }
  
  return (
    <div className="flex-1 flex flex-col items-center justify-center px-6 py-4">
      <div className="relative w-32 h-32 mb-4">
        <svg className="w-32 h-32 transform -rotate-90">
          <circle
            cx="64"
            cy="64"
            r="60"
            stroke="currentColor"
            strokeWidth="8"
            fill="none"
            className="text-secondary"
          />
          <circle
            cx="64"
            cy="64"
            r="60"
            stroke="currentColor"
            strokeWidth="8"
            fill="none"
            strokeDasharray={`${2 * Math.PI * 60}`}
            strokeDashoffset={`${2 * Math.PI * 60 * (1 - progress / 100)}`}
            className="text-primary transition-all duration-1000"
          />
        </svg>
        <div className="absolute inset-0 flex items-center justify-center">
          <span className="text-3xl font-mono">{formatTime(remaining)}</span>
        </div>
      </div>
      
      <div className="flex gap-2">
        {!isRunning || isPaused ? (
          <button
            onClick={start}
            className="p-2 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 transition-colors"
            aria-label="Start"
          >
            <Play className="w-5 h-5" />
          </button>
        ) : (
          <button
            onClick={pause}
            className="p-2 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 transition-colors"
            aria-label="Pause"
          >
            <Pause className="w-5 h-5" />
          </button>
        )}
        
        <button
          onClick={stop}
          className="p-2 bg-secondary rounded-lg hover:bg-secondary/80 transition-colors"
          aria-label="Stop"
        >
          <Square className="w-5 h-5" />
        </button>
        
        <button
          onClick={stop}
          className="p-2 bg-secondary rounded-lg hover:bg-secondary/80 transition-colors"
          aria-label="Reset"
        >
          <RotateCcw className="w-5 h-5" />
        </button>
      </div>
    </div>
  );
}