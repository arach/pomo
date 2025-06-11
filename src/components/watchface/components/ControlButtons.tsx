import { Play, Pause, Square, RotateCcw } from 'lucide-react';

interface ControlButtonsProps {
  isRunning: boolean;
  isPaused: boolean;
  onStart: () => void;
  onPause: () => void;
  onStop: () => void;
  onReset: () => void;
  style?: React.CSSProperties;
  buttonStyle?: 'gradient' | 'terminal' | 'minimal' | React.CSSProperties;
  showLabels?: boolean;
  size?: 'small' | 'medium' | 'large';
  position?: {
    x?: number | string;
    y?: number | string;
  };
}

export function ControlButtons({
  isRunning,
  isPaused,
  onStart,
  onPause,
  onStop,
  onReset,
  style,
  buttonStyle = 'gradient',
  showLabels = false,
  size = 'medium',
  position,
}: ControlButtonsProps) {
  const getButtonClass = () => {
    let padding = '';
    switch (size) {
      case 'small':
        padding = buttonStyle === 'terminal' ? 'px-2 py-1' : 'p-1.5';
        break;
      case 'large':
        padding = buttonStyle === 'terminal' ? 'px-4 py-3' : 'p-4';
        break;
      default:
        padding = buttonStyle === 'terminal' ? 'px-3 py-2' : 'p-3';
    }
    
    switch (buttonStyle) {
      case 'gradient':
        return `${padding} rounded-xl transition-all duration-300 hover:scale-105`;
      case 'terminal':
        return `${padding} border border-current transition-all hover:bg-current hover:text-black font-mono text-xs`;
      default:
        return `${padding} rounded-lg transition-colors`;
    }
  };

  const renderButton = (
    onClick: () => void,
    icon: React.ReactNode,
    label: string,
    primary?: boolean
  ) => {
    // If buttonStyle is an object, use inline styles
    if (typeof buttonStyle === 'object') {
      return (
        <button
          onClick={onClick}
          style={buttonStyle}
          className={showLabels ? 'flex items-center gap-2' : ''}
          aria-label={label}
        >
          {icon}
          {showLabels && <span className="text-sm">{label}</span>}
        </button>
      );
    }

    const baseClass = getButtonClass();
    const colorClass = buttonStyle === 'gradient' 
      ? primary 
        ? 'bg-gradient-to-br from-primary to-primary/80 text-primary-foreground hover:shadow-lg hover:shadow-primary/25'
        : 'bg-white/10 backdrop-blur-sm hover:bg-white/20'
      : '';

    return (
      <button
        onClick={onClick}
        className={`${baseClass} ${colorClass} ${showLabels ? 'flex items-center gap-2' : ''}`}
        aria-label={label}
      >
        {icon}
        {showLabels && <span className="text-sm">{label}</span>}
      </button>
    );
  };

  const iconSize = size === 'small' ? 'w-3 h-3' : size === 'large' ? 'w-6 h-6' : 'w-5 h-5';
  const gapSize = size === 'small' ? 'gap-1' : size === 'large' ? 'gap-4' : 'gap-3';
  
  const positionStyle: React.CSSProperties = {};
  
  if (position?.x === 'center' && typeof position?.y === 'number') {
    positionStyle.position = 'absolute';
    positionStyle.top = position.y;
    positionStyle.left = '50%';
    positionStyle.transform = 'translateX(-50%)';
  }
  
  const justifyClass = style?.justifyContent === 'flex-start' ? 'justify-start' : 'justify-center';
  
  return (
    <div className={`flex ${gapSize} ${justifyClass}`} style={{ ...positionStyle, ...style }}>
      {!isRunning || isPaused ? (
        renderButton(onStart, <Play className={iconSize} />, 'Start', true)
      ) : (
        renderButton(onPause, <Pause className={iconSize} />, 'Pause', true)
      )}
      
      {renderButton(onStop, <Square className={iconSize} />, 'Stop')}
      {renderButton(onReset, <RotateCcw className={iconSize} />, 'Reset')}
    </div>
  );
}