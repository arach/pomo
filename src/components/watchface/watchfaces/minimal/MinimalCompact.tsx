import { RotateCcw } from 'lucide-react';

interface MinimalCompactProps {
  remaining: number;
  progress: number;
  isRunning: boolean;
  isPaused: boolean;
  onStart: () => void;
  onPause: () => void;
  onStop: () => void;
}

export function MinimalCompact({
  remaining,
  progress,
  isRunning,
  isPaused,
  onStart,
  onPause,
  onStop
}: MinimalCompactProps) {
  const formatTime = (seconds: number) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  };

  const handleAction = () => {
    if (!isRunning || isPaused) {
      onStart();
    } else {
      onPause();
    }
  };

  return (
    <div style={{ 
      display: 'flex', 
      flexDirection: 'column', 
      gap: '12px',
      width: '140px'
    }}>
      {/* Time and controls in one line */}
      <div style={{ 
        display: 'flex', 
        alignItems: 'center', 
        justifyContent: 'space-between',
        gap: '12px'
      }}>
        <div 
          onClick={handleAction}
          style={{
            fontSize: '32px',
            fontWeight: '300',
            letterSpacing: '-0.02em',
            fontFeatureSettings: "'tnum'",
            cursor: 'pointer',
            userSelect: 'none',
            opacity: 0.9,
            transition: 'opacity 0.2s',
            minWidth: '90px'
          }}
          onMouseEnter={(e) => e.currentTarget.style.opacity = '1'}
          onMouseLeave={(e) => e.currentTarget.style.opacity = '0.9'}
        >
          {formatTime(remaining)}
        </div>
        
        <button
          onClick={onStop}
          style={{
            background: 'transparent',
            border: 'none',
            padding: '4px',
            cursor: 'pointer',
            opacity: 0.4,
            transition: 'opacity 0.2s',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center'
          }}
          onMouseEnter={(e) => e.currentTarget.style.opacity = '0.7'}
          onMouseLeave={(e) => e.currentTarget.style.opacity = '0.4'}
          aria-label="Reset"
        >
          <RotateCcw className="w-3 h-3" />
        </button>
      </div>
      
      {/* Progress bar */}
      <div style={{
        width: '100%',
        height: '2px',
        background: 'currentColor',
        opacity: 0.1,
        borderRadius: '1px',
        overflow: 'hidden'
      }}>
        <div style={{
          width: `${progress}%`,
          height: '100%',
          background: 'currentColor',
          opacity: 0.4,
          transition: 'width 0.3s ease-out',
          borderRadius: '1px'
        }} />
      </div>
      
      {/* Status indicator */}
      <div style={{
        fontSize: '9px',
        opacity: 0.5,
        letterSpacing: '0.05em',
        textTransform: 'uppercase'
      }}>
        {!isRunning ? 'Ready' : isPaused ? 'Paused' : 'Focus'}
      </div>
    </div>
  );
}