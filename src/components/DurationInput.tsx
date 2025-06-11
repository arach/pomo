import { useState, useEffect, useRef } from 'react';
import { useTimerStore } from '../stores/timer-store';
import { Clock, Coffee, Target, Brain, Zap, X } from 'lucide-react';
import { SessionTypeSelector } from './SessionTypeSelector';

interface DurationInputProps {
  isVisible?: boolean;
  onDismiss?: () => void;
}

export function DurationInput({ isVisible = true, onDismiss }: DurationInputProps) {
  const { duration, setDuration, isRunning } = useTimerStore();
  const [minutes, setMinutes] = useState(Math.floor(duration / 60).toString());
  const [seconds, setSeconds] = useState((duration % 60).toString());
  const [selectedPreset, setSelectedPreset] = useState<number | null>(null);
  const [isAnimating, setIsAnimating] = useState(false);
  const containerRef = useRef<HTMLDivElement>(null);
  
  useEffect(() => {
    const currentMinutes = Math.floor(duration / 60);
    const currentSeconds = duration % 60;
    
    // Check if current duration matches a preset
    if (currentSeconds === 0) {
      if ([5, 15, 25, 45].includes(currentMinutes)) {
        setSelectedPreset(currentMinutes);
      } else {
        setSelectedPreset(null);
      }
    } else {
      setSelectedPreset(null);
    }
  }, [duration]);

  useEffect(() => {
    setIsAnimating(true);
  }, []);

  useEffect(() => {
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        dismiss();
      }
    };

    const handleClickOutside = (e: MouseEvent) => {
      if (containerRef.current && !containerRef.current.contains(e.target as Node)) {
        dismiss();
      }
    };

    document.addEventListener('keydown', handleEscape);
    document.addEventListener('mousedown', handleClickOutside);

    return () => {
      document.removeEventListener('keydown', handleEscape);
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, []);
  
  const dismiss = () => {
    setIsAnimating(false);
    // Just dismiss without starting - timer will be in "ready" state
    setTimeout(() => {
      onDismiss?.();
    }, 200);
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    const mins = parseInt(minutes) || 0;
    const secs = parseInt(seconds) || 0;
    const totalSeconds = mins * 60 + secs;
    
    if (totalSeconds > 0 && totalSeconds <= 59999) { // Max ~16.6 hours
      setDuration(totalSeconds);
      setTimeout(() => dismiss(), 150);
    }
  };
  
  const handlePreset = (value: number) => {
    setMinutes(value.toString());
    setSeconds('0');
    setDuration(value * 60);
    setSelectedPreset(value);
    setTimeout(() => dismiss(), 150);
  };
  
  const presets = [
    { label: '5m', value: 5, icon: Coffee, desc: 'Quick break' },
    { label: '15m', value: 15, icon: Zap, desc: 'Short focus' },
    { label: '25m', value: 25, icon: Target, desc: 'Pomodoro' },
    { label: '45m', value: 45, icon: Brain, desc: 'Deep work' },
  ];
  
  if (isRunning || !isVisible) return null;
  
  return (
    <div 
      ref={containerRef}
      className={`px-4 pb-4 transition-all duration-200 ${
        isAnimating 
          ? 'opacity-100 transform translate-y-0' 
          : 'opacity-0 transform translate-y-2'
      }`}
      style={{
        animation: isAnimating ? 'slideInFromBottom 0.3s ease-out' : 'slideOutToBottom 0.2s ease-in'
      }}
    >
      <div className="relative">
        <button
          onClick={dismiss}
          className="absolute -top-2 -right-2 p-1 rounded-full bg-black/40 backdrop-blur-sm border border-white/10 hover:bg-white/20 hover:border-white/20 transition-all"
          title="Close (Esc)"
        >
          <X className="w-3 h-3 text-white/70" />
        </button>
        
        {/* Session Type Selector */}
        <div className="mb-3">
          <div className="text-xs text-muted-foreground/70 mb-2 text-center">Session Type</div>
          <SessionTypeSelector compact />
        </div>
        
        <form onSubmit={handleSubmit} className="mb-3">
          <div className="flex items-center gap-3 p-3 bg-black/40 backdrop-blur-sm rounded-lg border border-white/10">
            <Clock className="w-4 h-4 text-muted-foreground/70" />
            <div className="flex items-baseline gap-1 flex-1">
              <input
                type="number"
                value={minutes}
                onChange={(e) => {
                  setMinutes(e.target.value);
                  setSelectedPreset(null);
                }}
                min="0"
                max="999"
                className="w-14 px-2 py-1.5 bg-white/20 backdrop-blur-sm rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-white/30 text-center font-mono font-medium transition-all hover:bg-white/25"
                placeholder="25"
                autoFocus
              />
              <span className="text-muted-foreground/50 text-lg font-light">:</span>
              <input
                type="number"
                value={seconds}
                onChange={(e) => {
                  setSeconds(e.target.value);
                  setSelectedPreset(null);
                }}
                min="0"
                max="59"
                className="w-14 px-2 py-1.5 bg-white/20 backdrop-blur-sm rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-white/30 text-center font-mono font-medium transition-all hover:bg-white/25"
                placeholder="00"
              />
            </div>
            <button
              type="submit"
              className="px-4 py-1.5 bg-white/30 backdrop-blur-sm text-white rounded-md text-sm hover:bg-white/40 active:bg-white/50 transition-all font-medium border border-white/20 hover:border-white/30 shadow-sm"
            >
              Set Timer
            </button>
          </div>
        </form>
      </div>
      
      <div className="grid grid-cols-4 gap-2">
        {presets.map((preset) => {
          const Icon = preset.icon;
          const isSelected = selectedPreset === preset.value;
          
          return (
            <button
              key={preset.value}
              onClick={() => handlePreset(preset.value)}
              className={`
                relative group flex flex-col items-center p-3 rounded-lg
                transition-all duration-200 transform
                ${isSelected 
                  ? 'bg-white/30 border-white/40 shadow-lg scale-105' 
                  : 'bg-black/40 border-white/10 hover:bg-white/20 hover:border-white/20 hover:scale-105'
                }
                border backdrop-blur-sm
                active:scale-95
              `}
            >
              <Icon className={`
                w-5 h-5 mb-1 transition-colors
                ${isSelected ? 'text-white' : 'text-muted-foreground/70 group-hover:text-white/90'}
              `} />
              <span className={`
                text-sm font-medium transition-colors
                ${isSelected ? 'text-white' : 'text-white/80 group-hover:text-white'}
              `}>
                {preset.label}
              </span>
              <span className={`
                text-[10px] mt-0.5 transition-all
                ${isSelected ? 'opacity-70' : 'opacity-0 group-hover:opacity-50'}
              `}>
                {preset.desc}
              </span>
              {isSelected && (
                <div className="absolute inset-0 rounded-lg ring-2 ring-white/30 ring-offset-2 ring-offset-transparent" />
              )}
            </button>
          );
        })}
      </div>
      
      <div className="mt-3 text-center text-[10px] text-muted-foreground/50">
        Press <kbd className="px-1 py-0.5 bg-white/20 rounded text-white/70">Esc</kbd> or click outside to close
      </div>
    </div>
  );
}