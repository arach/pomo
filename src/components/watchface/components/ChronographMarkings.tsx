import React from 'react';

interface ChronographMarkingsProps {
  style?: React.CSSProperties;
}

export function ChronographMarkings({ style }: ChronographMarkingsProps) {
  // Create markings for 12, 3, 6, 9 o'clock positions (major marks)
  // and smaller marks for 5-minute intervals
  const majorMarks = [0, 90, 180, 270]; // 12, 3, 6, 9 o'clock
  const minorMarks = [30, 60, 120, 150, 210, 240, 300, 330]; // 5-minute intervals
  
  return (
    <div style={{ ...style, position: 'relative' }}>
      {/* Major markings (12, 3, 6, 9) */}
      {majorMarks.map((angle) => (
        <div
          key={`major-${angle}`}
          style={{
            position: 'absolute',
            width: '3px',
            height: '16px',
            background: 'rgba(255, 255, 255, 0.8)',
            top: '50%',
            left: '50%',
            transformOrigin: '50% 0%',
            transform: `translate(-50%, -78px) rotate(${angle}deg)`,
          }}
        />
      ))}
      
      {/* Minor markings (5-minute intervals) */}
      {minorMarks.map((angle) => (
        <div
          key={`minor-${angle}`}
          style={{
            position: 'absolute',
            width: '1px',
            height: '8px',
            background: 'rgba(255, 255, 255, 0.4)',
            top: '50%',
            left: '50%',
            transformOrigin: '50% 0%',
            transform: `translate(-50%, -78px) rotate(${angle}deg)`,
          }}
        />
      ))}
      
      {/* 12 o'clock indicator (start position) */}
      <div
        style={{
          position: 'absolute',
          width: '0',
          height: '0',
          top: '6px',
          left: '50%',
          transform: 'translateX(-50%)',
          borderLeft: '4px solid transparent',
          borderRight: '4px solid transparent',
          borderBottom: '8px solid hsl(217.2, 91.2%, 59.8%)',
        }}
      />
      
      {/* Center dot */}
      <div
        style={{
          position: 'absolute',
          width: '6px',
          height: '6px',
          background: 'white',
          borderRadius: '50%',
          top: '50%',
          left: '50%',
          transform: 'translate(-50%, -50%)',
          boxShadow: '0 0 4px rgba(0,0,0,0.3)',
        }}
      />
    </div>
  );
}