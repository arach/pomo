import { useState } from 'react';
import { useTimerStore } from '../stores/timer-store';
import { Clock } from 'lucide-react';

export function DurationInput() {
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
  
  if (isRunning) return null;
  
  return (
    <div className="px-4 pb-4">
      <form onSubmit={handleSubmit} className="flex gap-2 mb-2">
        <div className="flex-1 flex gap-1">
          <div className="flex-1 relative">
            <Clock className="absolute left-2 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
            <input
              type="number"
              value={minutes}
              onChange={(e) => setMinutes(e.target.value)}
              min="0"
              max="999"
              className="w-full pl-8 pr-2 py-2 bg-secondary rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary text-center"
              placeholder="MM"
            />
          </div>
          <span className="flex items-center text-muted-foreground">:</span>
          <div className="flex-1">
            <input
              type="number"
              value={seconds}
              onChange={(e) => setSeconds(e.target.value)}
              min="0"
              max="59"
              className="w-full px-2 py-2 bg-secondary rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary text-center"
              placeholder="SS"
            />
          </div>
        </div>
        <button
          type="submit"
          className="px-3 py-2 bg-primary text-primary-foreground rounded-lg text-sm hover:bg-primary/90 transition-colors"
        >
          Set
        </button>
      </form>
      
      <div className="flex gap-1">
        {presets.map((preset) => (
          <button
            key={preset.value}
            onClick={() => handlePreset(preset.value)}
            className="flex-1 py-1 text-xs bg-secondary rounded hover:bg-secondary/80 transition-colors"
          >
            {preset.label}
          </button>
        ))}
      </div>
    </div>
  );
}