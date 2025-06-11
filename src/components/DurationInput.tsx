import { useState } from 'react';
import { useTimerStore } from '../stores/timer-store';
import { Clock } from 'lucide-react';

interface DurationInputProps {
  isVisible?: boolean;
}

export function DurationInput({ isVisible = true }: DurationInputProps) {
  const { duration, setDuration, isRunning } = useTimerStore();
  const [minutes, setMinutes] = useState(Math.floor(duration / 60).toString());
  const [seconds, setSeconds] = useState((duration % 60).toString());
  
  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    const mins = parseInt(minutes) || 0;
    const secs = parseInt(seconds) || 0;
    const totalSeconds = mins * 60 + secs;
    
    if (totalSeconds > 0 && totalSeconds <= 59999) { // Max ~16.6 hours
      setDuration(totalSeconds);
    }
  };
  
  const handlePreset = (value: number) => {
    setMinutes(value.toString());
    setSeconds('0');
    setDuration(value * 60);
  };
  
  const presets = [
    { label: '5m', value: 5 },
    { label: '15m', value: 15 },
    { label: '25m', value: 25 },
    { label: '45m', value: 45 },
  ];
  
  if (isRunning || !isVisible) return null;
  
  return (
    <div className="px-3 pb-3">
      <form onSubmit={handleSubmit} className="flex gap-2 mb-2">
        <div className="flex-1 flex items-center gap-1">
          <Clock className="w-3 h-3 text-muted-foreground flex-shrink-0" />
          <input
            type="number"
            value={minutes}
            onChange={(e) => setMinutes(e.target.value)}
            min="0"
            max="999"
            className="w-12 px-1 py-1.5 bg-secondary rounded-md text-sm focus:outline-none focus:ring-1 focus:ring-primary text-center"
            placeholder="25"
          />
          <span className="text-muted-foreground text-sm">:</span>
          <input
            type="number"
            value={seconds}
            onChange={(e) => setSeconds(e.target.value)}
            min="0"
            max="59"
            className="w-12 px-1 py-1.5 bg-secondary rounded-md text-sm focus:outline-none focus:ring-1 focus:ring-primary text-center"
            placeholder="00"
          />
          <button
            type="submit"
            className="ml-auto px-3 py-1.5 bg-primary text-primary-foreground rounded-md text-sm hover:bg-primary/90 transition-colors font-medium"
          >
            Set
          </button>
        </div>
      </form>
      
      <div className="flex gap-1">
        {presets.map((preset) => (
          <button
            key={preset.value}
            onClick={() => handlePreset(preset.value)}
            className="flex-1 py-1 text-xs bg-secondary rounded-md hover:bg-secondary/80 transition-colors"
          >
            {preset.label}
          </button>
        ))}
      </div>
    </div>
  );
}