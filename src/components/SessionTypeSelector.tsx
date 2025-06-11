import { SessionType, useTimerStore } from '../stores/timer-store';
import { Brain, Coffee, ClipboardList, BarChart3, BookOpen } from 'lucide-react';
import { LucideIcon } from 'lucide-react';

const sessionTypes: { type: SessionType; icon: LucideIcon; label: string }[] = [
  { type: 'focus', icon: Brain, label: 'Deep Focus' },
  { type: 'break', icon: Coffee, label: 'Break' },
  { type: 'planning', icon: ClipboardList, label: 'Planning' },
  { type: 'review', icon: BarChart3, label: 'Review' },
  { type: 'learning', icon: BookOpen, label: 'Learning' },
];

interface SessionTypeSelectorProps {
  compact?: boolean;
  iconOnly?: boolean;
}

export function SessionTypeSelector({ compact = false, iconOnly = false }: SessionTypeSelectorProps) {
  const { sessionType, setSessionType, isRunning } = useTimerStore();
  
  const handleTypeSelect = (type: SessionType) => {
    if (!isRunning) {
      setSessionType(type);
    }
  };
  
  if (iconOnly) {
    return (
      <div className="flex gap-1 justify-center">
        {sessionTypes.map(({ type, icon: Icon, label }) => (
          <button
            key={type}
            onClick={() => handleTypeSelect(type)}
            disabled={isRunning}
            className={`
              p-1.5 rounded
              transition-all duration-200
              ${sessionType === type 
                ? 'bg-white/20 text-white' 
                : 'bg-black/20 text-white/60 hover:bg-white/10 hover:text-white/80'
              }
              ${isRunning ? 'opacity-50 cursor-not-allowed' : 'cursor-pointer'}
              border border-white/10
            `}
            title={label}
          >
            <Icon className="w-3.5 h-3.5" />
          </button>
        ))}
      </div>
    );
  }
  
  if (compact) {
    return (
      <div className="flex gap-1 justify-center">
        {sessionTypes.map(({ type, icon: Icon }) => (
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
            <Icon className="w-4 h-4 text-white/80" />
          </button>
        ))}
      </div>
    );
  }
  
  return (
    <div className="flex flex-wrap gap-2 justify-center p-4">
      {sessionTypes.map(({ type, icon: Icon, label }) => (
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
          <Icon className="w-5 h-5 text-muted-foreground" />
          <span className="text-xs font-medium">{label}</span>
        </button>
      ))}
    </div>
  );
}