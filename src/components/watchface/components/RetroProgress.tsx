import React from 'react';

interface RetroProgressProps {
  progress: number;
  style?: React.CSSProperties;
}

export function RetroProgress({ progress, style }: RetroProgressProps) {
  const segments = 20;
  const filledSegments = Math.floor((progress / 100) * segments);
  
  return (
    <div style={style} className="retro-progress">
      <div
        className="progress-fill"
        style={{
          position: 'absolute',
          top: 0,
          left: 0,
          height: '100%',
          width: `${progress}%`,
          background: 'linear-gradient(90deg, #ffcc00 0%, #ffcc00 90%, #ff9900 100%)',
          boxShadow: '0 0 10px #ffcc00',
          transition: 'width 0.5s ease-out'
        }}
      />
      <div
        className="progress-segments"
        style={{
          position: 'absolute',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          display: 'flex',
          gap: '2px'
        }}
      >
        {Array.from({ length: segments }).map((_, i) => (
          <div
            key={i}
            style={{
              flex: 1,
              background: i < filledSegments ? 'transparent' : 'rgba(0,0,0,0.3)',
              borderRight: '1px solid #0a0a0a'
            }}
          />
        ))}
      </div>
    </div>
  );
}