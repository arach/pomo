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
    { label: '25m', value: 25, icon: Target, desc: 'Focus' },
    { label: '45m', value: 45, icon: Brain, desc: 'Deep work' },
  ];
  
  if (isRunning || !isVisible) return null;
  
  return (
    <div 
      ref={containerRef}
      className="px-3 pb-3"
      style={{
        opacity: isAnimating ? 1 : 0,
        transform: isAnimating ? 'translateY(0)' : 'translateY(10px)',
        transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
        background: 'linear-gradient(to top, rgba(0,0,0,0.95) 0%, rgba(0,0,0,0.90) 100%)',
        backdropFilter: 'blur(20px)',
        WebkitBackdropFilter: 'blur(20px)',
        willChange: 'transform, opacity'
      }}
    >
      <div className="relative pt-2">
        <button
          onClick={dismiss}
          className="absolute -top-0.5 -right-0.5 p-0.5 rounded-full bg-black/40 backdrop-blur-sm border border-white/10 hover:bg-white/20 hover:border-white/20 transition-all z-10"
          title="Close (Esc)"
          data-tauri-drag-region="false"
        >
          <X className="w-3 h-3 text-white/70" />
        </button>
        
        {/* Time Input - First Priority */}
        <form onSubmit={handleSubmit} className="mb-2">
          <div className="flex items-center gap-2 p-2 bg-black/40 backdrop-blur-sm rounded-md border border-white/10">
            <Clock className="w-3.5 h-3.5 text-muted-foreground/70" />
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
                className="w-12 px-1.5 py-1 bg-white/20 backdrop-blur-sm rounded text-sm focus:outline-none focus:ring-1 focus:ring-white/30 text-center font-mono font-medium transition-all hover:bg-white/25"
                placeholder="25"
                autoFocus
                data-tauri-drag-region="false"
              />
              <span className="text-muted-foreground/50 text-base font-light">:</span>
              <input
                type="number"
                value={seconds}
                onChange={(e) => {
                  setSeconds(e.target.value);
                  setSelectedPreset(null);
                }}
                min="0"
                max="59"
                className="w-12 px-1.5 py-1 bg-white/20 backdrop-blur-sm rounded text-sm focus:outline-none focus:ring-1 focus:ring-white/30 text-center font-mono font-medium transition-all hover:bg-white/25"
                placeholder="00"
                data-tauri-drag-region="false"
              />
            </div>
            <button
              type="submit"
              className="px-3 py-1 bg-white/30 backdrop-blur-sm text-white rounded text-sm hover:bg-white/40 active:bg-white/50 transition-all font-medium border border-white/20 hover:border-white/30"
              data-tauri-drag-region="false"
            >
              Set Timer
            </button>
          </div>
        </form>
      </div>
      
      {/* Presets - Second Priority */}
      <div className="grid grid-cols-4 gap-1.5 mb-2">
        {presets.map((preset) => {
          const Icon = preset.icon;
          const isSelected = selectedPreset === preset.value;
          
          return (
            <button
              key={preset.value}
              onClick={() => handlePreset(preset.value)}
              className={`
                relative group flex flex-col items-center py-2 px-1 rounded-md
                transition-all duration-200
                ${isSelected 
                  ? 'bg-white/25 border-white/40' 
                  : 'bg-black/30 border-white/10 hover:bg-white/15 hover:border-white/20'
                }
                border backdrop-blur-sm
                active:scale-95
              `}
              data-tauri-drag-region="false"
            >
              <Icon className={`
                w-4 h-4 mb-0.5 transition-colors
                ${isSelected ? 'text-white' : 'text-muted-foreground/70 group-hover:text-white/90'}
              `} />
              <span className={`
                text-xs font-medium transition-colors
                ${isSelected ? 'text-white' : 'text-white/80 group-hover:text-white'}
              `}>
                {preset.label}
              </span>
              <span className={`
                text-[9px] leading-tight transition-all whitespace-nowrap
                ${isSelected ? 'opacity-60' : 'opacity-0 group-hover:opacity-40'}
              `}>
                {preset.desc}
              </span>
            </button>
          );
        })}
      </div>
      
      {/* Session Type - Third Priority */}
      <div className="border-t border-white/10 pt-2">
        <SessionTypeSelector compact iconOnly />
      </div>
      
      <div className="mt-2 text-center text-[9px] text-muted-foreground/40">
        Press <kbd className="px-0.5 py-0.25 bg-white/15 rounded text-[8px] text-white/60">Esc</kbd> or click outside to close
      </div>
    </div>
  );
}