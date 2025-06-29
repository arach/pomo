import { Play, RotateCcw, Pause } from 'lucide-react';
import { SessionType } from '../../../../stores/timer-store';

interface DefaultLayoutProps {
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
  sessionName?: string | null;
}

const sessionLabels: Record<SessionType, string> = {
  focus: 'DEEP FOCUS',
  break: 'BREAK TIME',
  planning: 'PLANNING',
  review: 'REVIEW',
  learning: 'LEARNING'
};

export function DefaultLayout({
  remaining,
  duration: _duration,
  progress,
  isRunning,
  isPaused,
  onStart,
  onPause,
  onReset,
  onTimeClick,
  sessionType,
  sessionName
}: DefaultLayoutProps) {
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
      padding: '0px 20px 16px',
      fontFamily: "'Inter', -apple-system, BlinkMacSystemFont, sans-serif",
      color: '#ffffff'
    }}>
      {/* Progress Ring with Session Type */}
      <div style={{
        position: 'relative',
        width: '110px',
        height: '110px',
        marginBottom: '8px'
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
            r="52"
            fill="none"
            stroke="rgba(255, 255, 255, 0.08)"
            strokeWidth="3"
          />
          {/* Progress circle */}
          <circle
            cx="55"
            cy="55"
            r="52"
            fill="none"
            stroke="#4a9eff"
            strokeWidth="3"
            strokeDasharray={`${2 * Math.PI * 52}`}
            strokeDashoffset={`${2 * Math.PI * 52 * (1 - progress / 100)}`}
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
            fontSize: '9px',
            fontWeight: '500',
            letterSpacing: '0.8px',
            color: 'rgba(255, 255, 255, 0.5)',
            textTransform: 'uppercase',
            marginBottom: '1px'
          }}>
            {sessionLabels[sessionType]}
          </div>
          <div style={{
            fontSize: '11px',
            color: 'rgba(255, 255, 255, 0.3)',
            fontWeight: '400'
          }}>
            {Math.round(progress)}%
          </div>
        </div>
      </div>

      {/* Time Display */}
      <div 
        onClick={handleTimeClick}
        style={{
          fontSize: '36px',
          fontWeight: '300',
          letterSpacing: '-1.5px',
          fontFeatureSettings: '"tnum"',
          cursor: !isRunning ? 'pointer' : 'default',
          marginBottom: sessionName ? '6px' : '10px',
          fontFamily: "'JetBrains Mono', monospace",
          color: '#ffffff'
        }}
      >
        {formatTime(remaining)}
      </div>

      {/* Session Name */}
      {sessionName && (
        <div style={{
          fontSize: '12px',
          fontWeight: '500',
          color: 'rgba(255, 255, 255, 0.5)',
          marginBottom: '12px',
          textAlign: 'center',
          maxWidth: '180px',
          overflow: 'hidden',
          textOverflow: 'ellipsis',
          whiteSpace: 'nowrap'
        }}>
          {sessionName}
        </div>
      )}

      {/* Controls */}
      <div style={{
        display: 'flex',
        gap: '8px',
        width: '100%',
        maxWidth: '180px'
      }}>
        <button
          onClick={isRunning && !isPaused ? onPause : onStart}
          style={{
            flex: 1,
            height: '36px',
            background: 'transparent',
            color: '#ffffff',
            border: '1px solid rgba(255, 255, 255, 0.15)',
            borderRadius: '18px',
            fontSize: '13px',
            fontWeight: '500',
            letterSpacing: '0.02em',
            cursor: 'pointer',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            gap: '6px',
            transition: 'all 0.2s cubic-bezier(0.4, 0, 0.2, 1)',
            fontFamily: "'Inter', sans-serif"
          }}
          onMouseDown={(e) => {
            e.currentTarget.style.transform = 'scale(0.95)';
            e.currentTarget.style.borderColor = '#4a9eff';
            e.currentTarget.style.color = '#4a9eff';
            e.currentTarget.style.background = 'rgba(74, 158, 255, 0.1)';
          }}
          onMouseUp={(e) => {
            e.currentTarget.style.transform = 'scale(1)';
            e.currentTarget.style.borderColor = 'rgba(255, 255, 255, 0.15)';
            e.currentTarget.style.color = '#ffffff';
            e.currentTarget.style.background = 'transparent';
          }}
          onMouseLeave={(e) => {
            e.currentTarget.style.transform = 'scale(1)';
            e.currentTarget.style.borderColor = 'rgba(255, 255, 255, 0.15)';
            e.currentTarget.style.color = '#ffffff';
            e.currentTarget.style.background = 'transparent';
          }}
        >
          {isRunning && !isPaused ? (
            <><Pause size={14} strokeWidth={2} /> Pause</>
          ) : (
            <><Play size={14} strokeWidth={2} /> Start</>
          )}
        </button>

        <button
          onClick={onReset}
          style={{
            width: '80px',
            height: '36px',
            background: 'transparent',
            color: 'rgba(255, 255, 255, 0.4)',
            border: '1px solid rgba(255, 255, 255, 0.08)',
            borderRadius: '16px',
            fontSize: '13px',
            fontWeight: '500',
            letterSpacing: '0.02em',
            cursor: 'pointer',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            gap: '6px',
            transition: 'all 0.2s cubic-bezier(0.4, 0, 0.2, 1)',
            fontFamily: "'Inter', sans-serif"
          }}
          onMouseDown={(e) => {
            e.currentTarget.style.transform = 'scale(0.95)';
            e.currentTarget.style.borderColor = 'rgba(255, 255, 255, 0.15)';
            e.currentTarget.style.color = 'rgba(255, 255, 255, 0.7)';
            e.currentTarget.style.background = 'rgba(255, 255, 255, 0.05)';
          }}
          onMouseUp={(e) => {
            e.currentTarget.style.transform = 'scale(1)';
            e.currentTarget.style.borderColor = 'rgba(255, 255, 255, 0.08)';
            e.currentTarget.style.color = 'rgba(255, 255, 255, 0.4)';
            e.currentTarget.style.background = 'transparent';
          }}
          onMouseLeave={(e) => {
            e.currentTarget.style.transform = 'scale(1)';
            e.currentTarget.style.borderColor = 'rgba(255, 255, 255, 0.08)';
            e.currentTarget.style.color = 'rgba(255, 255, 255, 0.4)';
            e.currentTarget.style.background = 'transparent';
          }}
        >
          <RotateCcw size={14} strokeWidth={2} /> Reset
        </button>
      </div>
    </div>
  );
}