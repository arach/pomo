import React from 'react';

interface RetroProgressProps {
  progress: number;
  style?: React.CSSProperties;
}

export function RetroProgress({ progress, style }: RetroProgressProps) {
  const totalLEDs = 40;
  const activeLEDs = Math.floor((progress / 100) * totalLEDs);
  
  const getLEDColor = (index: number) => {
    const percentage = (index / totalLEDs) * 100;
    if (percentage < 60) return '#00ff00';
    if (percentage < 80) return '#ffcc00';
    return '#ff3333';
  };
  
  return (
    <div style={{
      ...style,
      position: 'absolute',
      top: 0,
      left: 0,
      right: 0,
      height: '8px',
      background: 'linear-gradient(to bottom, rgba(0,0,0,0.9), rgba(0,0,0,0.7))',
      boxShadow: 'inset 0 1px 3px rgba(0,0,0,0.8), 0 1px 0 rgba(255,255,255,0.1)',
      display: 'flex',
      alignItems: 'center',
      padding: '0 10px',
      gap: '2px'
    }} className="retro-progress">
      {Array.from({ length: totalLEDs }).map((_, i) => {
        const isActive = i < activeLEDs;
        const color = getLEDColor(i);
        
        return (
          <div
            key={i}
            style={{
              flex: 1,
              height: '4px',
              background: isActive ? color : 'rgba(40, 30, 20, 0.5)',
              boxShadow: isActive 
                ? `0 0 8px ${color}, inset 0 0 2px rgba(255,255,255,0.3)` 
                : 'inset 0 0 2px rgba(0,0,0,0.5)',
              borderRadius: '1px',
              transition: 'all 0.2s',
              transform: isActive ? 'scaleY(1.2)' : 'scaleY(1)',
              filter: isActive ? 'brightness(1.3)' : 'brightness(0.3)'
            }}
          />
        );
      })}
    </div>
  );
}