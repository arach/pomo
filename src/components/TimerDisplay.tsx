import { Play, Pause, Square, RotateCcw, Settings } from 'lucide-react';
import { useTimerStore } from '../stores/timer-store';
import { useSettingsStore } from '../stores/settings-store';
import { useEffect, useState } from 'react';

interface TimerDisplayProps {
  isCollapsed?: boolean;
}

export function TimerDisplay({ isCollapsed = false }: TimerDisplayProps) {
  const { duration, remaining, isRunning, isPaused, start, pause, stop } = useTimerStore();
  const { toggleSettings } = useSettingsStore();
  const [isAnimating, setIsAnimating] = useState(false);
  
  const formatTime = (seconds: number) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  };
  
  const progress = duration > 0 ? ((duration - remaining) / duration) * 100 : 0;
  
  useEffect(() => {
    if (remaining === 0 && duration > 0) {
      setIsAnimating(true);
      setTimeout(() => setIsAnimating(false), 1000);
    }
  }, [remaining, duration]);
  
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
    <div className="flex-1 flex flex-col items-center justify-center px-6 py-6 relative">
      {/* Settings button */}
      <button
        onClick={toggleSettings}
        className="absolute top-2 right-2 p-1.5 hover:bg-white/10 rounded-lg transition-all duration-200 hover:rotate-90"
        aria-label="Settings"
      >
        <Settings className="w-4 h-4 text-muted-foreground" />
      </button>
      
      {/* Timer circle */}
      <div className={`relative w-36 h-36 mb-6 ${isAnimating ? 'animate-pulse' : ''}`}>
        <div className="absolute inset-0 rounded-full bg-gradient-to-br from-primary/20 to-primary/5 blur-xl" />
        
        <svg className="w-36 h-36 transform -rotate-90 relative z-10">
          <defs>
            <linearGradient id="progressGradient" x1="0%" y1="0%" x2="100%" y2="100%">
              <stop offset="0%" stopColor="hsl(217.2, 91.2%, 59.8%)" />
              <stop offset="100%" stopColor="hsl(217.2, 91.2%, 69.8%)" />
            </linearGradient>
          </defs>
          
          {/* Background circle */}
          <circle
            cx="72"
            cy="72"
            r="66"
            stroke="currentColor"
            strokeWidth="6"
            fill="none"
            className="text-white/5"
          />
          
          {/* Progress circle */}
          <circle
            cx="72"
            cy="72"
            r="66"
            stroke="url(#progressGradient)"
            strokeWidth="6"
            fill="none"
            strokeDasharray={`${2 * Math.PI * 66}`}
            strokeDashoffset={`${2 * Math.PI * 66 * (1 - progress / 100)}`}
            className="transition-all duration-1000 ease-linear"
            strokeLinecap="round"
          />
        </svg>
        
        <div className="absolute inset-0 flex flex-col items-center justify-center">
          <span className="text-4xl font-light tabular-nums tracking-tight">
            {formatTime(remaining)}
          </span>
          <span className="text-xs text-muted-foreground mt-1">
            {isRunning ? (isPaused ? 'Paused' : 'Running') : 'Ready'}
          </span>
        </div>
      </div>
      
      {/* Control buttons */}
      <div className="flex gap-3">
        {!isRunning || isPaused ? (
          <button
            onClick={start}
            className="group relative p-3 bg-gradient-to-br from-primary to-primary/80 text-primary-foreground rounded-xl hover:shadow-lg hover:shadow-primary/25 transition-all duration-300 hover:scale-105"
            aria-label="Start"
          >
            <Play className="w-5 h-5 relative z-10" />
            <div className="absolute inset-0 rounded-xl bg-white opacity-0 group-hover:opacity-20 transition-opacity" />
          </button>
        ) : (
          <button
            onClick={pause}
            className="group relative p-3 bg-gradient-to-br from-orange-500 to-orange-600 text-white rounded-xl hover:shadow-lg hover:shadow-orange-500/25 transition-all duration-300 hover:scale-105"
            aria-label="Pause"
          >
            <Pause className="w-5 h-5 relative z-10" />
            <div className="absolute inset-0 rounded-xl bg-white opacity-0 group-hover:opacity-20 transition-opacity" />
          </button>
        )}
        
        <button
          onClick={stop}
          className="group relative p-3 bg-white/10 backdrop-blur-sm rounded-xl hover:bg-white/20 transition-all duration-300 hover:scale-105"
          aria-label="Stop"
        >
          <Square className="w-5 h-5" />
        </button>
        
        <button
          onClick={stop}
          className="group relative p-3 bg-white/10 backdrop-blur-sm rounded-xl hover:bg-white/20 transition-all duration-300 hover:scale-105"
          aria-label="Reset"
        >
          <RotateCcw className="w-5 h-5" />
        </button>
      </div>
    </div>
  );
}