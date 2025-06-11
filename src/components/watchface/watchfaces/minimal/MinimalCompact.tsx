import { Play, Pause, RotateCcw } from 'lucide-react';

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

  const handlePlayPause = () => {
    if (!isRunning || isPaused) {
      onStart();
    } else {
      onPause();
    }
  };

  // Use CSS variables for theme-aware colors
  const isDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
  const backgroundColor = isDark ? 'rgba(255, 255, 255, 0.05)' : 'rgba(0, 0, 0, 0.03)';
  const borderColor = isDark ? 'rgba(255, 255, 255, 0.1)' : 'rgba(0, 0, 0, 0.08)';
  const textColor = isDark ? 'rgba(255, 255, 255, 0.9)' : 'rgba(0, 0, 0, 0.9)';
  const mutedColor = isDark ? 'rgba(255, 255, 255, 0.5)' : 'rgba(0, 0, 0, 0.5)';
  const progressBg = isDark ? 'rgba(255, 255, 255, 0.1)' : 'rgba(0, 0, 0, 0.06)';
  const progressFill = isDark ? 'rgba(255, 255, 255, 0.3)' : 'rgba(0, 0, 0, 0.2)';

  return (
    <div style={{ 
      display: 'flex', 
      flexDirection: 'column', 
      gap: '10px',
      padding: '16px',
      background: backgroundColor,
      border: `1px solid ${borderColor}`,
      borderRadius: '12px',
      width: '180px',
      backdropFilter: 'blur(10px)'
    }}>
      {/* Timer display */}
      <div style={{
        fontSize: '36px',
        fontWeight: '500',
        letterSpacing: '-0.03em',
        fontFeatureSettings: "'tnum'",
        color: textColor,
        fontFamily: '-apple-system, BlinkMacSystemFont, "SF Pro Display", sans-serif',
        textAlign: 'center',
        lineHeight: 1
      }}>
        {formatTime(remaining)}
      </div>
      
      {/* Progress bar */}
      <div style={{
        width: '100%',
        height: '3px',
        background: progressBg,
        borderRadius: '1.5px',
        overflow: 'hidden',
        position: 'relative'
      }}>
        <div style={{
          width: `${progress}%`,
          height: '100%',
          background: progressFill,
          transition: 'width 0.5s cubic-bezier(0.4, 0, 0.2, 1)',
          borderRadius: '1.5px',
          position: 'absolute',
          left: 0,
          top: 0
        }} />
      </div>
      
      {/* Controls */}
      <div style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        gap: '12px',
        marginTop: '4px'
      }}>
        <button
          onClick={handlePlayPause}
          style={{
            background: 'transparent',
            border: `1px solid ${borderColor}`,
            borderRadius: '50%',
            width: '32px',
            height: '32px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            cursor: 'pointer',
            color: textColor,
            transition: 'all 0.2s ease',
            padding: 0
          }}
          onMouseEnter={(e) => {
            e.currentTarget.style.background = isDark ? 'rgba(255, 255, 255, 0.1)' : 'rgba(0, 0, 0, 0.05)';
            e.currentTarget.style.transform = 'scale(1.05)';
          }}
          onMouseLeave={(e) => {
            e.currentTarget.style.background = 'transparent';
            e.currentTarget.style.transform = 'scale(1)';
          }}
          aria-label={!isRunning || isPaused ? "Start" : "Pause"}
        >
          {!isRunning || isPaused ? (
            <Play className="w-3 h-3" style={{ marginLeft: '1px' }} />
          ) : (
            <Pause className="w-3 h-3" />
          )}
        </button>
        
        <button
          onClick={onStop}
          style={{
            background: 'transparent',
            border: 'none',
            padding: '6px',
            cursor: 'pointer',
            color: mutedColor,
            transition: 'all 0.2s ease',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            borderRadius: '50%'
          }}
          onMouseEnter={(e) => {
            e.currentTarget.style.color = textColor;
            e.currentTarget.style.transform = 'scale(1.1)';
          }}
          onMouseLeave={(e) => {
            e.currentTarget.style.color = mutedColor;
            e.currentTarget.style.transform = 'scale(1)';
          }}
          aria-label="Reset"
        >
          <RotateCcw className="w-3.5 h-3.5" />
        </button>
      </div>
      
      {/* Status text */}
      <div style={{
        fontSize: '10px',
        color: mutedColor,
        letterSpacing: '0.05em',
        textTransform: 'uppercase',
        textAlign: 'center',
        fontWeight: '500'
      }}>
        {remaining <= 0 ? 'Complete' : !isRunning ? 'Ready' : isPaused ? 'Paused' : 'Focus'}
      </div>
    </div>
  );
}