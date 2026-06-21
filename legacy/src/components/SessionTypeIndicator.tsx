import { SessionType } from '../stores/timer-store';
import { Brain, Coffee, ClipboardList, BarChart3, BookOpen, LucideIcon } from 'lucide-react';

interface SessionTypeIndicatorProps {
  type: SessionType;
  className?: string;
  size?: 'sm' | 'md' | 'lg';
  showLabel?: boolean;
}

const sessionConfig: Record<SessionType, {
  icon: LucideIcon;
  label: string;
  color: string;
  bgColor: string;
  borderColor: string;
}> = {
  focus: {
    icon: Brain,
    label: 'Deep Focus',
    color: 'text-purple-500',
    bgColor: 'bg-purple-500/10',
    borderColor: 'border-purple-500/20'
  },
  break: {
    icon: Coffee,
    label: 'Break',
    color: 'text-green-500',
    bgColor: 'bg-green-500/10',
    borderColor: 'border-green-500/20'
  },
  planning: {
    icon: ClipboardList,
    label: 'Planning',
    color: 'text-blue-500',
    bgColor: 'bg-blue-500/10',
    borderColor: 'border-blue-500/20'
  },
  review: {
    icon: BarChart3,
    label: 'Review',
    color: 'text-orange-500',
    bgColor: 'bg-orange-500/10',
    borderColor: 'border-orange-500/20'
  },
  learning: {
    icon: BookOpen,
    label: 'Learning',
    color: 'text-cyan-500',
    bgColor: 'bg-cyan-500/10',
    borderColor: 'border-cyan-500/20'
  }
};

export function SessionTypeIndicator({ type, className = '', size = 'md', showLabel = false }: SessionTypeIndicatorProps) {
  const config = sessionConfig[type];
  const Icon = config.icon;
  
  const sizeClasses = {
    sm: 'w-6 h-6',
    md: 'w-8 h-8',
    lg: 'w-10 h-10'
  };
  
  const iconSizes = {
    sm: 'w-3 h-3',
    md: 'w-4 h-4',
    lg: 'w-5 h-5'
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
        <Icon className={`${iconSizes[size]} ${config.color}`} />
      </div>
      {showLabel && (
        <span className={`text-sm font-medium ${config.color}`}>
          {config.label}
        </span>
      )}
    </div>
  );
}