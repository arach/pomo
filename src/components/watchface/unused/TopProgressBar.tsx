import React from 'react';

interface TopProgressBarProps {
  progress: number;
  style?: React.CSSProperties;
}

export function TopProgressBar({ progress, style }: TopProgressBarProps) {
  const progressColor = (style as any)?.progressColor || '#00ff00';
  
  return (
    <div
      style={{
        position: 'absolute',
        top: 0,
        left: 0,
        right: 0,
        height: '2px',
        background: 'rgba(0, 255, 0, 0.1)',
        ...style
      }}
    >
      <div
        style={{
          height: '100%',
          width: `${progress}%`,
          background: progressColor,
          transition: 'width 0.3s ease-out',
          boxShadow: `0 0 4px ${progressColor}`
        }}
      />
    </div>
  );
}