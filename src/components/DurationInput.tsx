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
  const [focusedPresetIndex, setFocusedPresetIndex] = useState<number>(0); // Start with first preset focused
  const [isAnimating, setIsAnimating] = useState(false);
  const containerRef = useRef<HTMLDivElement>(null);
  const minutesRef = useRef<HTMLInputElement>(null);
  const secondsRef = useRef<HTMLInputElement>(null);
  const presetRefs = useRef<(HTMLButtonElement | null)[]>([]);
  
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
    // Focus first preset on mount instead of minutes input
    setTimeout(() => {
      presetRefs.current[0]?.focus();
    }, 100);
  }, []);

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      // Handle Escape key
      if (e.key === 'Escape') {
        dismiss();
        return;
      }
      
      // Handle Tab navigation between inputs
      if (e.key === 'Tab' && !e.shiftKey) {
        if (document.activeElement === minutesRef.current) {
          e.preventDefault();
          secondsRef.current?.focus();
          secondsRef.current?.select();
          return;
        }
      }
      
      // Handle Shift+Tab navigation
      if (e.key === 'Tab' && e.shiftKey) {
        if (document.activeElement === secondsRef.current) {
          e.preventDefault();
          minutesRef.current?.focus();
          minutesRef.current?.select();
          return;
        }
      }
      
      // Handle arrow key and vim navigation for inputs (only when not typing)
      if (document.activeElement === minutesRef.current || document.activeElement === secondsRef.current) {
        // Only handle vim keys if not combined with other modifiers (to allow normal typing)
        const isVimNavigation = !e.ctrlKey && !e.metaKey && !e.altKey && !e.shiftKey;
        
        if (e.key === 'ArrowRight' || (e.key === 'l' && isVimNavigation)) {
          if (document.activeElement === minutesRef.current) {
            e.preventDefault();
            secondsRef.current?.focus();
            secondsRef.current?.select();
          }
        } else if (e.key === 'ArrowLeft' || (e.key === 'h' && isVimNavigation)) {
          if (document.activeElement === secondsRef.current) {
            e.preventDefault();
            minutesRef.current?.focus();
            minutesRef.current?.select();
          }
        } else if (e.key === 'ArrowDown' || (e.key === 'j' && isVimNavigation)) {
          // Move down to presets from either input
          e.preventDefault();
          setFocusedPresetIndex(0);
          presetRefs.current[0]?.focus();
        } else if (e.key === 'ArrowUp' || (e.key === 'k' && isVimNavigation)) {
          // k/up does nothing when already in inputs (already at top)
          e.preventDefault();
        }
      }
      
      // Handle 'm' and 's' keys to focus inputs (only when NOT already in inputs)
      const isInInput = document.activeElement === minutesRef.current || 
                       document.activeElement === secondsRef.current;
      
      if (!isInInput && !e.ctrlKey && !e.metaKey && !e.altKey) {
        if (e.key === 'm' || e.key === 'M') {
          e.preventDefault();
          minutesRef.current?.focus();
          minutesRef.current?.select();
          setFocusedPresetIndex(-1);
          return;
        }
        
        if (e.key === 's' || e.key === 'S') {
          e.preventDefault();
          secondsRef.current?.focus();
          secondsRef.current?.select();
          setFocusedPresetIndex(-1);
          return;
        }
      }
      
      // Handle number keys 1-4 for preset selection (only when NOT in input fields)
      if (!e.ctrlKey && !e.metaKey && !e.altKey && !isInInput) {
        const key = parseInt(e.key);
        if (key >= 1 && key <= 4) {
          e.preventDefault();
          const presetValues = [5, 15, 25, 45];
          handlePreset(presetValues[key - 1]);
        }
      }
      
      // Handle arrow keys and vim navigation for preset navigation
      if ((e.key === 'ArrowDown' || e.key === 'j') && focusedPresetIndex === -1) {
        e.preventDefault();
        setFocusedPresetIndex(0);
        presetRefs.current[0]?.focus();
      } else if ((e.key === 'ArrowLeft' || e.key === 'h') && focusedPresetIndex > 0) {
        e.preventDefault();
        setFocusedPresetIndex(focusedPresetIndex - 1);
        presetRefs.current[focusedPresetIndex - 1]?.focus();
      } else if ((e.key === 'ArrowRight' || e.key === 'l') && focusedPresetIndex >= 0 && focusedPresetIndex < 3) {
        e.preventDefault();
        setFocusedPresetIndex(focusedPresetIndex + 1);
        presetRefs.current[focusedPresetIndex + 1]?.focus();
      } else if ((e.key === 'ArrowUp' || e.key === 'k') && focusedPresetIndex >= 0) {
        e.preventDefault();
        setFocusedPresetIndex(-1);
        minutesRef.current?.focus();
      }
    };

    const handleClickOutside = (e: MouseEvent) => {
      if (containerRef.current && !containerRef.current.contains(e.target as Node)) {
        dismiss();
      }
    };

    document.addEventListener('keydown', handleKeyDown);
    document.addEventListener('mousedown', handleClickOutside);

    return () => {
      document.removeEventListener('keydown', handleKeyDown);
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, [focusedPresetIndex, onDismiss]);
  
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
          className="absolute -top-0.5 -right-0.5 p-0.5 rounded-full bg-black/40 backdrop-blur-sm border border-white/10 hover:bg-white/20 hover:border-white/20 transition-all z-10 focus:outline-none focus:ring-2 focus:ring-white/40"
          title="Close (Esc)"
          data-tauri-drag-region="false"
          tabIndex={-1}
        >
          <X className="w-3 h-3 text-white/70" />
        </button>
        
        {/* Time Input - First Priority */}
        <form onSubmit={handleSubmit} className="mb-2">
          <div className="flex items-center gap-2 p-2 bg-black/40 backdrop-blur-sm rounded-md border border-white/10">
            <Clock className="w-3.5 h-3.5 text-muted-foreground/70" />
            <div className="flex items-baseline gap-1 flex-1">
              <input
                ref={minutesRef}
                type="number"
                value={minutes}
                onChange={(e) => {
                  // Only allow numeric input
                  const value = e.target.value.replace(/[^0-9]/g, '');
                  setMinutes(value);
                  setSelectedPreset(null);
                }}
                onFocus={(e) => {
                  e.target.select();
                  setFocusedPresetIndex(-1);
                }}
                onKeyDown={(e) => {
                  if (e.key === 'Enter') {
                    e.preventDefault();
                    handleSubmit(e as any);
                  }
                }}
                onKeyPress={(e) => {
                  // Prevent non-numeric characters
                  if (!/[0-9]/.test(e.key)) {
                    e.preventDefault();
                  }
                }}
                min="0"
                max="999"
                className="w-12 px-1.5 py-1 bg-white/20 backdrop-blur-sm rounded text-sm focus:outline-none focus:ring-2 focus:ring-white/40 text-center font-mono font-medium transition-all hover:bg-white/25"
                placeholder="25"
                data-tauri-drag-region="false"
              />
              <span className="text-muted-foreground/50 text-base font-light">:</span>
              <input
                ref={secondsRef}
                type="number"
                value={seconds}
                onChange={(e) => {
                  // Only allow numeric input
                  const value = e.target.value.replace(/[^0-9]/g, '');
                  setSeconds(value);
                  setSelectedPreset(null);
                }}
                onFocus={(e) => {
                  e.target.select();
                  setFocusedPresetIndex(-1);
                }}
                onKeyDown={(e) => {
                  if (e.key === 'Enter') {
                    e.preventDefault();
                    handleSubmit(e as any);
                  }
                }}
                onKeyPress={(e) => {
                  // Prevent non-numeric characters
                  if (!/[0-9]/.test(e.key)) {
                    e.preventDefault();
                  }
                }}
                min="0"
                max="59"
                className="w-12 px-1.5 py-1 bg-white/20 backdrop-blur-sm rounded text-sm focus:outline-none focus:ring-2 focus:ring-white/40 text-center font-mono font-medium transition-all hover:bg-white/25"
                placeholder="00"
                data-tauri-drag-region="false"
              />
            </div>
            <button
              type="submit"
              className="px-3 py-1 bg-white/30 backdrop-blur-sm text-white rounded text-sm hover:bg-white/40 active:bg-white/50 transition-all font-medium border border-white/20 hover:border-white/30 focus:outline-none focus:ring-2 focus:ring-white/40"
              data-tauri-drag-region="false"
              title="Set timer (Enter)"
            >
              Set Timer
            </button>
          </div>
        </form>
      </div>
      
      {/* Presets - Second Priority */}
      <div className="grid grid-cols-4 gap-1.5 mb-2">
        {presets.map((preset, index) => {
          const Icon = preset.icon;
          const isSelected = selectedPreset === preset.value;
          const isFocused = focusedPresetIndex === index;
          
          return (
            <button
              ref={(el) => presetRefs.current[index] = el}
              key={preset.value}
              onClick={() => handlePreset(preset.value)}
              onFocus={() => setFocusedPresetIndex(index)}
              onBlur={() => setFocusedPresetIndex(-1)}
              onKeyDown={(e) => {
                if (e.key === 'Enter' || e.key === ' ') {
                  e.preventDefault();
                  handlePreset(preset.value);
                }
              }}
              className={`
                relative group flex flex-col items-center py-2 px-1 rounded-md
                transition-all duration-200
                ${isSelected 
                  ? 'bg-white/25 border-white/40' 
                  : isFocused
                    ? 'bg-white/20 border-white/30 ring-2 ring-white/40'
                    : 'bg-black/30 border-white/10 hover:bg-white/15 hover:border-white/20'
                }
                border backdrop-blur-sm
                active:scale-95
                focus:outline-none focus:ring-2 focus:ring-white/40
              `}
              data-tauri-drag-region="false"
              title={`Press ${index + 1} for ${preset.desc}`}
            >
              <Icon className={`
                w-4 h-4 mb-0.5 transition-colors
                ${isSelected || isFocused ? 'text-white' : 'text-muted-foreground/70 group-hover:text-white/90'}
              `} />
              <span className={`
                text-xs font-medium transition-colors
                ${isSelected || isFocused ? 'text-white' : 'text-white/80 group-hover:text-white'}
              `}>
                {preset.label}
              </span>
              <span className={`
                text-[9px] leading-tight transition-all whitespace-nowrap
                ${isSelected || isFocused ? 'opacity-60' : 'opacity-0 group-hover:opacity-40'}
              `}>
                {preset.desc}
              </span>
              {index < 4 && (
                <kbd className="absolute top-1 right-1 px-1 py-0.5 text-[8px] bg-black/40 rounded opacity-40 group-hover:opacity-60">
                  {index + 1}
                </kbd>
              )}
            </button>
          );
        })}
      </div>
      
      {/* Session Type - Third Priority */}
      <div className="border-t border-white/10 pt-2">
        <SessionTypeSelector compact iconOnly />
      </div>
      
      <div className="mt-2 text-center text-[9px] text-muted-foreground/40 space-y-0.5">
        <div>
          Press <kbd className="px-0.5 py-0.25 bg-white/15 rounded text-[8px] text-white/60">1-4</kbd> for presets • 
          <kbd className="px-0.5 py-0.25 bg-white/15 rounded text-[8px] text-white/60">m</kbd> for minutes • 
          <kbd className="px-0.5 py-0.25 bg-white/15 rounded text-[8px] text-white/60">s</kbd> for seconds
        </div>
        <div>
          Navigate: <kbd className="px-0.5 py-0.25 bg-white/15 rounded text-[8px] text-white/60">h j k l</kbd> or arrows • 
          <kbd className="px-0.5 py-0.25 bg-white/15 rounded text-[8px] text-white/60">Tab</kbd> between inputs • 
          <kbd className="px-0.5 py-0.25 bg-white/15 rounded text-[8px] text-white/60">Enter</kbd> to set • 
          <kbd className="px-0.5 py-0.25 bg-white/15 rounded text-[8px] text-white/60">Esc</kbd> to close
        </div>
      </div>
    </div>
  );
}