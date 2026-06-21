import { Play, RotateCcw, Pause } from 'lucide-react';
import { SessionType } from '../../../../../stores/timer-store';

interface DefaultLayoutV2Props {
  remaining: number;
  duration: number;
  progress: number;
  isRunning: boolean;
  isPaused: boolean;
  onStart: () => void;
  onPause: () => void;
  onReset: () => void;
  onTimeClick?: () => void;
  sessionType: SessionType;
}

const sessionLabels: Record<SessionType, string> = {
  focus: 'DEEP FOCUS',
  break: 'BREAK TIME',
  planning: 'PLANNING',
  review: 'REVIEW',
  learning: 'LEARNING'
};

export function DefaultLayoutV2({
  remaining,
  duration: _duration,
  progress,
  isRunning,
  isPaused,
  onStart,
  onPause,
  onReset,
  onTimeClick,
  sessionType
}: DefaultLayoutV2Props) {
  const formatTime = (seconds: number): string => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  };

  const handleTimeClick = () => {
    if (!isRunning && onTimeClick) {
      onTimeClick();
    }
  };

  return (
    <div style={{
      width: '100%',
      height: '100%',
      position: 'relative',
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      justifyContent: 'center',
      padding: '10px',
      fontFamily: "'Inter', -apple-system, BlinkMacSystemFont, sans-serif",
      color: '#f0f0f0'
    }}>
      {/* V2 indicator */}
      <div style={{
        position: 'absolute',
        top: 10,
        right: 10,
        background: 'rgba(255, 255, 255, 0.1)',
        backdropFilter: 'blur(10px)',
        color: '#fff',
        padding: '2px 8px',
        borderRadius: '12px',
        fontSize: '10px',
        fontWeight: 'bold',
        border: '1px solid rgba(255, 255, 255, 0.2)'
      }}>
        V2
      </div>
      
      {/* Glass-morphism background */}
      <div style={{
        position: 'absolute',
        inset: '20px',
        background: 'rgba(255, 255, 255, 0.03)',
        backdropFilter: 'blur(20px)',
        borderRadius: '20px',
        border: '1px solid rgba(255, 255, 255, 0.1)',
        zIndex: -1
      }} />
      
      {/* Progress Ring with Session Type */}
      <div style={{
        position: 'relative',
        width: '110px',
        height: '110px',
        marginBottom: '4px',
        filter: 'drop-shadow(0 4px 20px rgba(74, 158, 255, 0.3))'
      }}>
        <svg
          width="110"
          height="110"
          style={{ transform: 'rotate(-90deg)' }}
        >
          {/* Gradient definition */}
          <defs>
            <linearGradient id="progressGradient" x1="0%" y1="0%" x2="100%" y2="100%">
              <stop offset="0%" stopColor="#4a9eff" stopOpacity="1" />
              <stop offset="100%" stopColor="#00d4ff" stopOpacity="1" />
            </linearGradient>
          </defs>
          
          {/* Background circle with subtle glow */}
          <circle
            cx="55"
            cy="55"
            r="51"
            fill="none"
            stroke="rgba(255, 255, 255, 0.1)"
            strokeWidth="6"
          />
          <circle
            cx="55"
            cy="55"
            r="51"
            fill="none"
            stroke="rgba(74, 158, 255, 0.2)"
            strokeWidth="8"
            opacity="0.5"
            filter="blur(2px)"
          />
          
          {/* Progress circle with gradient */}
          <circle
            cx="55"
            cy="55"
            r="51"
            fill="none"
            stroke="url(#progressGradient)"
            strokeWidth="6"
            strokeDasharray={`${2 * Math.PI * 51}`}
            strokeDashoffset={`${2 * Math.PI * 51 * (1 - progress / 100)}`}
            strokeLinecap="round"
            style={{
              transition: 'stroke-dashoffset 0.5s cubic-bezier(0.4, 0, 0.2, 1)',
              filter: 'drop-shadow(0 0 6px rgba(74, 158, 255, 0.6))'
            }}
          />
        </svg>
        
        {/* Session Type and Progress inside circle */}
        <div style={{
          position: 'absolute',
          top: '50%',
          left: '50%',
          transform: 'translate(-50%, -50%)',
          textAlign: 'center',
          lineHeight: '1.2'
        }}>
          <div style={{
            fontSize: '10px',
            fontWeight: '600',
            letterSpacing: '0.3px',
            color: '#888888',
            textTransform: 'uppercase',
            marginBottom: '1px'
          }}>
            {sessionLabels[sessionType]}
          </div>
          <div style={{
            fontSize: '10px',
            color: '#666666',
            fontWeight: '500'
          }}>
            {Math.round(progress)}%
          </div>
        </div>
      </div>

      {/* Time Display with glass effect */}
      <div 
        onClick={handleTimeClick}
        style={{
          fontSize: '34px',
          fontWeight: '300',
          letterSpacing: '-1px',
          cursor: !isRunning ? 'pointer' : 'default',
          marginBottom: '8px',
          fontFamily: "'JetBrains Mono', monospace",
          color: '#f0f0f0',
          textShadow: '0 2px 10px rgba(0, 0, 0, 0.3)',
          transition: 'transform 0.2s ease',
          transform: !isRunning ? 'scale(1)' : 'scale(1)',
        }}
        onMouseEnter={(e) => {
          if (!isRunning) {
            e.currentTarget.style.transform = 'scale(1.05)';
          }
        }}
        onMouseLeave={(e) => {
          e.currentTarget.style.transform = 'scale(1)';
        }}
      >
        {formatTime(remaining)}
      </div>

      {/* Glass-morphism Controls */}
      <div style={{
        display: 'flex',
        gap: '6px',
        width: '100%',
        maxWidth: '180px'
      }}>
        <button
          onClick={isRunning && !isPaused ? onPause : onStart}
          style={{
            flex: 1,
            height: '32px',
            background: 'rgba(255, 255, 255, 0.1)',
            backdropFilter: 'blur(10px)',
            color: '#f0f0f0',
            border: '1px solid rgba(255, 255, 255, 0.2)',
            borderRadius: '16px',
            fontSize: '12px',
            fontWeight: '500',
            cursor: 'pointer',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            gap: '4px',
            transition: 'all 0.2s cubic-bezier(0.4, 0, 0.2, 1)',
            fontFamily: "'Inter', sans-serif"
          }}
          onMouseDown={(e) => {
            e.currentTarget.style.transform = 'scale(0.95)';
            e.currentTarget.style.background = 'rgba(74, 158, 255, 0.2)';
            e.currentTarget.style.borderColor = '#4a9eff';
            e.currentTarget.style.color = '#4a9eff';
          }}
          onMouseUp={(e) => {
            e.currentTarget.style.transform = 'scale(1)';
            e.currentTarget.style.background = 'rgba(255, 255, 255, 0.1)';
            e.currentTarget.style.borderColor = 'rgba(255, 255, 255, 0.2)';
            e.currentTarget.style.color = '#f0f0f0';
          }}
          onMouseLeave={(e) => {
            e.currentTarget.style.transform = 'scale(1)';
            e.currentTarget.style.background = 'rgba(255, 255, 255, 0.1)';
            e.currentTarget.style.borderColor = 'rgba(255, 255, 255, 0.2)';
            e.currentTarget.style.color = '#f0f0f0';
          }}
          onMouseEnter={(e) => {
            e.currentTarget.style.background = 'rgba(255, 255, 255, 0.15)';
            e.currentTarget.style.borderColor = 'rgba(255, 255, 255, 0.3)';
          }}
        >
          {isRunning && !isPaused ? (
            <><Pause size={14} /> Pause</>
          ) : (
            <><Play size={14} /> Start</>
          )}
        </button>

        <button
          onClick={onReset}
          style={{
            width: '60px',
            height: '32px',
            background: 'rgba(255, 255, 255, 0.05)',
            backdropFilter: 'blur(10px)',
            color: '#888888',
            border: '1px solid rgba(255, 255, 255, 0.1)',
            borderRadius: '16px',
            fontSize: '12px',
            fontWeight: '500',
            cursor: 'pointer',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            gap: '4px',
            transition: 'all 0.2s cubic-bezier(0.4, 0, 0.2, 1)',
            fontFamily: "'Inter', sans-serif"
          }}
          onMouseDown={(e) => {
            e.currentTarget.style.transform = 'scale(0.95)';
            e.currentTarget.style.borderColor = 'rgba(255, 255, 255, 0.2)';
            e.currentTarget.style.color = '#f0f0f0';
          }}
          onMouseUp={(e) => {
            e.currentTarget.style.transform = 'scale(1)';
            e.currentTarget.style.borderColor = 'rgba(255, 255, 255, 0.1)';
            e.currentTarget.style.color = '#888888';
          }}
          onMouseLeave={(e) => {
            e.currentTarget.style.transform = 'scale(1)';
            e.currentTarget.style.borderColor = 'rgba(255, 255, 255, 0.1)';
            e.currentTarget.style.color = '#888888';
          }}
          onMouseEnter={(e) => {
            e.currentTarget.style.background = 'rgba(255, 255, 255, 0.08)';
            e.currentTarget.style.borderColor = 'rgba(255, 255, 255, 0.15)';
          }}
        >
          <RotateCcw size={14} /> Reset
        </button>
      </div>
    </div>
  );
}