import React from 'react';

interface LCDProgressProps {
  progress: number;
  style?: React.CSSProperties;
}

export function LCDProgress({ progress, style }: LCDProgressProps) {
  const segments = 10;
  const filledSegments = Math.floor((progress / 100) * segments);
  
  return (
    <div style={{
      ...style,
      display: 'flex',
      gap: '8px',
      padding: '10px 16px',
      background: 'rgba(0, 0, 0, 0.8)',
      borderRadius: '8px',
      boxShadow: 'inset 0 2px 4px rgba(0, 0, 0, 0.5), 0 1px 0 rgba(255, 204, 0, 0.1)'
    }}>
      {Array.from({ length: segments }).map((_, i) => {
        const isActive = i < filledSegments;
        return (
          <div
            key={i}
            style={{
              width: '14px',
              height: '28px',
              background: isActive 
                ? 'linear-gradient(to bottom, #ffcc00, #ff9900)' 
                : 'rgba(100, 80, 40, 0.2)',
              boxShadow: isActive 
                ? '0 0 20px #ffcc00, inset 0 0 10px rgba(255, 255, 255, 0.3)' 
                : 'inset 0 1px 2px rgba(0, 0, 0, 0.3)',
              borderRadius: '2px',
              transition: 'all 0.3s',
              transform: isActive ? 'scale(1.05)' : 'scale(1)',
              border: '1px solid rgba(0, 0, 0, 0.3)'
            }}
          />
        );
      })}
      <div style={{
        marginLeft: '12px',
        fontSize: '16px',
        fontFamily: "'Orbitron', monospace",
        fontWeight: '700',
        color: '#ffcc00',
        textShadow: '0 0 10px currentColor',
        lineHeight: '32px',
        minWidth: '45px'
      }}>
        {Math.round(progress)}%
      </div>
    </div>
  );
}