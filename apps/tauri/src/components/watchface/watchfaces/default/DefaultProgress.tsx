import React from 'react';

interface DefaultProgressProps {
  progress: number;
  style?: React.CSSProperties;
}

export function DefaultProgress({ progress, style }: DefaultProgressProps) {
  const radius = 80;
  const strokeWidth = 4;
  const normalizedRadius = radius - strokeWidth * 2;
  const circumference = normalizedRadius * 2 * Math.PI;
  const strokeDashoffset = circumference - (progress / 100) * circumference;
  
  return (
    <div style={{
      ...style,
      position: 'absolute',
      top: '50%',
      left: '50%',
      transform: 'translate(-50%, -50%)'
    }}>
      <svg
        width={radius * 2}
        height={radius * 2}
        style={{ transform: 'rotate(-90deg)' }}
      >
        {/* Background circle */}
        <circle
          stroke="rgba(255, 255, 255, 0.1)"
          fill="none"
          strokeWidth={strokeWidth}
          r={normalizedRadius}
          cx={radius}
          cy={radius}
        />
        
        {/* Progress circle */}
        <circle
          stroke="url(#defaultGradient)"
          fill="none"
          strokeWidth={strokeWidth}
          strokeDasharray={circumference + ' ' + circumference}
          strokeDashoffset={strokeDashoffset}
          strokeLinecap="round"
          r={normalizedRadius}
          cx={radius}
          cy={radius}
          style={{
            transition: 'stroke-dashoffset 0.5s cubic-bezier(0.4, 0, 0.2, 1)',
            filter: 'drop-shadow(0 2px 8px rgba(59, 130, 246, 0.3))'
          }}
        />
        
        {/* Gradient definition */}
        <defs>
          <linearGradient id="defaultGradient" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" stopColor="#3b82f6" stopOpacity="0.8" />
            <stop offset="50%" stopColor="#60a5fa" stopOpacity="1" />
            <stop offset="100%" stopColor="#3b82f6" stopOpacity="0.8" />
          </linearGradient>
        </defs>
      </svg>
      
      {/* Progress dots */}
      <div style={{
        position: 'absolute',
        top: '50%',
        left: '50%',
        width: radius * 2,
        height: radius * 2,
        transform: 'translate(-50%, -50%)',
        pointerEvents: 'none'
      }}>
        {[0, 25, 50, 75].map((marker) => {
          const angle = (marker * 3.6) - 90;
          const angleRad = (angle * Math.PI) / 180;
          const dotX = radius + normalizedRadius * Math.cos(angleRad);
          const dotY = radius + normalizedRadius * Math.sin(angleRad);
          const isActive = progress >= marker;
          
          return (
            <div
              key={marker}
              style={{
                position: 'absolute',
                width: '6px',
                height: '6px',
                borderRadius: '50%',
                background: isActive ? '#3b82f6' : 'rgba(255, 255, 255, 0.2)',
                left: `${dotX}px`,
                top: `${dotY}px`,
                transform: 'translate(-50%, -50%)',
                transition: 'all 0.3s',
                boxShadow: isActive ? '0 0 8px rgba(59, 130, 246, 0.6)' : 'none'
              }}
            />
          );
        })}
      </div>
      
      {/* Progress tip */}
      {progress > 0 && progress < 100 && (
        <div style={{
          position: 'absolute',
          top: '50%',
          left: '50%',
          width: radius * 2,
          height: radius * 2,
          transform: 'translate(-50%, -50%)',
          pointerEvents: 'none'
        }}>
          <div style={{
            position: 'absolute',
            width: '12px',
            height: '12px',
            borderRadius: '50%',
            background: '#60a5fa',
            boxShadow: '0 0 20px rgba(96, 165, 250, 0.8), 0 0 40px rgba(59, 130, 246, 0.4)',
            top: '50%',
            left: '50%',
            transform: `rotate(${(progress * 3.6) - 90}deg) translate(${normalizedRadius}px) translate(-50%, -50%)`,
            animation: 'pulse 2s ease-in-out infinite'
          }} />
        </div>
      )}
      
      <style dangerouslySetInnerHTML={{ __html: `
        @keyframes pulse {
          0%, 100% { transform: scale(1); opacity: 1; }
          50% { transform: scale(1.2); opacity: 0.8; }
        }
      `}} />
    </div>
  );
}