import { Play, RotateCcw, Pause } from 'lucide-react';
import { SessionType } from '../../../../stores/timer-store';

interface CleanLayoutProps {
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

export function CleanLayout({
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
}: CleanLayoutProps) {
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
      {/* Progress Ring with Session Type */}
      <div style={{
        position: 'relative',
        width: '110px',
        height: '110px',
        marginBottom: '4px'
      }}>
        <svg
          width="110"
          height="110"
          style={{ transform: 'rotate(-90deg)' }}
        >
          {/* Background circle */}
          <circle
            cx="55"
            cy="55"
            r="51"
            fill="none"
            stroke="#2a2a2a"
            strokeWidth="6"
          />
          {/* Progress circle */}
          <circle
            cx="55"
            cy="55"
            r="51"
            fill="none"
            stroke="#4a9eff"
            strokeWidth="6"
            strokeDasharray={`${2 * Math.PI * 51}`}
            strokeDashoffset={`${2 * Math.PI * 51 * (1 - progress / 100)}`}
            strokeLinecap="round"
            style={{
              transition: 'stroke-dashoffset 0.5s ease'
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

      {/* Time Display */}
      <div 
        onClick={handleTimeClick}
        style={{
          fontSize: '34px',
          fontWeight: '300',
          letterSpacing: '-1px',
          cursor: !isRunning ? 'pointer' : 'default',
          marginBottom: '8px',
          fontFamily: "'JetBrains Mono', monospace",
          color: '#f0f0f0'
        }}
      >
        {formatTime(remaining)}
      </div>

      {/* Controls */}
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
            background: 'transparent',
            color: '#f0f0f0',
            border: '1px solid #3a3a3a',
            borderRadius: '16px',
            fontSize: '12px',
            fontWeight: '500',
            cursor: 'pointer',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            gap: '4px',
            transition: 'all 0.15s ease',
            fontFamily: "'Inter', sans-serif"
          }}
          onMouseDown={(e) => {
            e.currentTarget.style.transform = 'scale(0.95)';
            e.currentTarget.style.borderColor = '#4a9eff';
            e.currentTarget.style.color = '#4a9eff';
          }}
          onMouseUp={(e) => {
            e.currentTarget.style.transform = 'scale(1)';
            e.currentTarget.style.borderColor = '#3a3a3a';
            e.currentTarget.style.color = '#f0f0f0';
          }}
          onMouseLeave={(e) => {
            e.currentTarget.style.transform = 'scale(1)';
            e.currentTarget.style.borderColor = '#3a3a3a';
            e.currentTarget.style.color = '#f0f0f0';
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
            background: 'transparent',
            color: '#888888',
            border: '1px solid #2a2a2a',
            borderRadius: '16px',
            fontSize: '12px',
            fontWeight: '500',
            cursor: 'pointer',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            gap: '4px',
            transition: 'all 0.15s ease',
            fontFamily: "'Inter', sans-serif"
          }}
          onMouseDown={(e) => {
            e.currentTarget.style.transform = 'scale(0.95)';
            e.currentTarget.style.borderColor = '#3a3a3a';
            e.currentTarget.style.color = '#f0f0f0';
          }}
          onMouseUp={(e) => {
            e.currentTarget.style.transform = 'scale(1)';
            e.currentTarget.style.borderColor = '#2a2a2a';
            e.currentTarget.style.color = '#888888';
          }}
          onMouseLeave={(e) => {
            e.currentTarget.style.transform = 'scale(1)';
            e.currentTarget.style.borderColor = '#2a2a2a';
            e.currentTarget.style.color = '#888888';
          }}
        >
          <RotateCcw size={14} /> Reset
        </button>
      </div>
    </div>
  );
}