import { SessionType, useTimerStore } from '../stores/timer-store';

const sessionTypes: { type: SessionType; icon: string; label: string }[] = [
  { type: 'focus', icon: '🧠', label: 'Deep Focus' },
  { type: 'break', icon: '☕', label: 'Break' },
  { type: 'planning', icon: '📋', label: 'Planning' },
  { type: 'review', icon: '📊', label: 'Review' },
  { type: 'learning', icon: '📚', label: 'Learning' },
];

interface SessionTypeSelectorProps {
  compact?: boolean;
}

export function SessionTypeSelector({ compact = false }: SessionTypeSelectorProps) {
  const { sessionType, setSessionType, isRunning } = useTimerStore();
  
  const handleTypeSelect = (type: SessionType) => {
    if (!isRunning) {
      setSessionType(type);
    }
  };
  
  if (compact) {
    return (
      <div className="flex gap-1 justify-center">
        {sessionTypes.map(({ type, icon }) => (
          <button
            key={type}
            onClick={() => handleTypeSelect(type)}
            disabled={isRunning}
            className={`
              p-2 rounded-lg
              transition-all duration-200
              ${sessionType === type 
                ? 'bg-white/30 shadow-sm' 
                : 'bg-black/20 hover:bg-white/10'
              }
              ${isRunning ? 'opacity-50 cursor-not-allowed' : 'cursor-pointer'}
              border border-white/10
            `}
            title={sessionTypes.find(t => t.type === type)?.label}
          >
            <span className="text-lg">{icon}</span>
          </button>
        ))}
      </div>
    );
  }
  
  return (
    <div className="flex flex-wrap gap-2 justify-center p-4">
      {sessionTypes.map(({ type, icon, label }) => (
        <button
          key={type}
          onClick={() => handleTypeSelect(type)}
          disabled={isRunning}
          className={`
            flex flex-col items-center gap-1 p-3 rounded-lg
            transition-all duration-200
            ${sessionType === type 
              ? 'bg-primary/20 border-primary/50 shadow-sm' 
              : 'bg-secondary/10 border-border/20 hover:bg-secondary/20'
            }
            ${isRunning ? 'opacity-50 cursor-not-allowed' : 'cursor-pointer'}
            border
          `}
        >
          <span className="text-xl">{icon}</span>
          <span className="text-xs font-medium">{label}</span>
        </button>
      ))}
    </div>
  );
}