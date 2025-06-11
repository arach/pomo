import { SessionType } from '../stores/timer-store';

interface SessionTypeIndicatorProps {
  type: SessionType;
  className?: string;
  size?: 'sm' | 'md' | 'lg';
  showLabel?: boolean;
}

const sessionConfig = {
  focus: {
    icon: '🧠',
    label: 'Deep Focus',
    color: 'text-purple-500',
    bgColor: 'bg-purple-500/10',
    borderColor: 'border-purple-500/20'
  },
  break: {
    icon: '☕',
    label: 'Break',
    color: 'text-green-500',
    bgColor: 'bg-green-500/10',
    borderColor: 'border-green-500/20'
  },
  planning: {
    icon: '📋',
    label: 'Planning',
    color: 'text-blue-500',
    bgColor: 'bg-blue-500/10',
    borderColor: 'border-blue-500/20'
  },
  review: {
    icon: '📊',
    label: 'Review',
    color: 'text-orange-500',
    bgColor: 'bg-orange-500/10',
    borderColor: 'border-orange-500/20'
  },
  learning: {
    icon: '📚',
    label: 'Learning',
    color: 'text-cyan-500',
    bgColor: 'bg-cyan-500/10',
    borderColor: 'border-cyan-500/20'
  }
};

export function SessionTypeIndicator({ type, className = '', size = 'md', showLabel = false }: SessionTypeIndicatorProps) {
  const config = sessionConfig[type];
  
  const sizeClasses = {
    sm: 'w-6 h-6 text-xs',
    md: 'w-8 h-8 text-sm',
    lg: 'w-10 h-10 text-base'
  };
  
  return (
    <div className={`flex items-center gap-2 ${className}`}>
      <div className={`
        ${sizeClasses[size]}
        ${config.bgColor}
        ${config.borderColor}
        border rounded-full
        flex items-center justify-center
        transition-all duration-200
        hover:scale-110
      `}>
        <span>{config.icon}</span>
      </div>
      {showLabel && (
        <span className={`text-sm font-medium ${config.color}`}>
          {config.label}
        </span>
      )}
    </div>
  );
}