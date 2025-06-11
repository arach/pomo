import React from 'react';

interface MinimalProgressProps {
  progress: number;
  style?: React.CSSProperties;
}

export function MinimalProgress({ progress, style }: MinimalProgressProps) {
  return (
    <div style={{ ...style, position: 'relative', overflow: 'hidden' }}>
      <div
        style={{
          position: 'absolute',
          top: 0,
          left: 0,
          height: '100%',
          width: `${progress}%`,
          background: 'hsl(var(--foreground))',
          transition: 'width 1s cubic-bezier(0.4, 0, 0.2, 1)'
        }}
      />
    </div>
  );
}