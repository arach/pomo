import React from 'react';

interface NeonProgressProps {
  progress: number;
  style?: React.CSSProperties;
}

export function NeonProgress({ progress, style }: NeonProgressProps) {
  // Fixed size for consistent appearance
  const size = 200;
  const center = size / 2;
  const strokeWidth = 3;
  const radius = 85;
  const circumference = radius * 2 * Math.PI;
  const strokeDashoffset = circumference - (progress / 100) * circumference;
  
  // Calculate progress position for end cap
  const angle = (progress / 100) * 2 * Math.PI - Math.PI / 2;
  const endX = center + radius * Math.cos(angle);
  const endY = center + radius * Math.sin(angle);
  
  return (
    <div style={{
      ...style,
      position: 'relative',
      width: size,
      height: size,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center'
    }}>
      {/* Subtle outer glow */}
      <div
        style={{
          position: 'absolute',
          width: size,
          height: size,
          borderRadius: '50%',
          background: `radial-gradient(circle at center, 
            transparent 65%, 
            rgba(255, 0, 255, 0.05) 75%, 
            rgba(0, 255, 255, 0.05) 85%, 
            transparent 100%)`,
          filter: 'blur(10px)'
        }}
      />
      
      {/* Main progress ring */}
      <svg
        width={size}
        height={size}
        style={{
          position: 'absolute',
          transform: 'rotate(-90deg)'
        }}
      >
        {/* Background track */}
        <circle
          stroke="rgba(255, 255, 255, 0.1)"
          fill="none"
          strokeWidth={strokeWidth}
          r={radius}
          cx={center}
          cy={center}
        />
        
        {/* Inner glow track */}
        <circle
          stroke="rgba(255, 0, 255, 0.15)"
          fill="none"
          strokeWidth={strokeWidth - 1}
          r={radius}
          cx={center}
          cy={center}
        />
        
        {/* Progress glow layer */}
        <circle
          stroke={`url(#neonGradient-${progress})`}
          fill="none"
          strokeWidth={strokeWidth + 2}
          strokeDasharray={circumference + ' ' + circumference}
          strokeDashoffset={strokeDashoffset}
          r={radius}
          cx={center}
          cy={center}
          opacity="0.5"
          style={{
            transition: 'stroke-dashoffset 0.5s ease-out',
            strokeLinecap: 'round',
            filter: 'blur(3px)'
          }}
        />
        
        {/* Progress stroke - crisp */}
        <circle
          stroke={`url(#neonGradient-${progress})`}
          fill="none"
          strokeWidth={strokeWidth}
          strokeDasharray={circumference + ' ' + circumference}
          strokeDashoffset={strokeDashoffset}
          r={radius}
          cx={center}
          cy={center}
          style={{
            transition: 'stroke-dashoffset 0.5s ease-out',
            strokeLinecap: 'round',
            filter: 'drop-shadow(0 0 2px rgba(255, 0, 255, 0.8))'
          }}
        />
        
        {/* Progress end cap */}
        {progress > 0 && progress < 100 && (
          <g transform={`rotate(90 ${center} ${center})`}>
            <circle
              fill="#fff"
              r={strokeWidth / 2}
              cx={endX}
              cy={endY}
              style={{
                filter: 'drop-shadow(0 0 4px #fff)',
                transition: 'all 0.5s ease-out'
              }}
            />
            <circle
              fill="rgba(255, 0, 255, 0.8)"
              r={strokeWidth / 2 + 3}
              cx={endX}
              cy={endY}
              opacity="0.6"
              style={{
                filter: 'blur(2px)',
                transition: 'all 0.5s ease-out'
              }}
            />
          </g>
        )}
        
        {/* Gradient definition */}
        <defs>
          <linearGradient 
            id={`neonGradient-${progress}`} 
            x1="0%" 
            y1="0%" 
            x2="100%" 
            y2="100%"
          >
            <stop offset="0%" stopColor="#ff00ff" />
            <stop offset="50%" stopColor="#00ffff" />
            <stop offset="100%" stopColor="#ff00ff" />
          </linearGradient>
          
          {/* Add some crisp patterns */}
          <pattern id="neonDots" x="0" y="0" width="4" height="4" patternUnits="userSpaceOnUse">
            <circle cx="2" cy="2" r="0.5" fill="rgba(255, 255, 255, 0.1)" />
          </pattern>
        </defs>
      </svg>
      
      {/* Inner ring details */}
      <svg
        width={size}
        height={size}
        style={{
          position: 'absolute',
          pointerEvents: 'none'
        }}
      >
        {/* Tick marks */}
        {[...Array(12)].map((_, i) => {
          const tickAngle = (i * 30) * Math.PI / 180;
          const x1 = center + (radius - 10) * Math.cos(tickAngle);
          const y1 = center + (radius - 10) * Math.sin(tickAngle);
          const x2 = center + (radius - 5) * Math.cos(tickAngle);
          const y2 = center + (radius - 5) * Math.sin(tickAngle);
          
          return (
            <line
              key={i}
              x1={x1}
              y1={y1}
              x2={x2}
              y2={y2}
              stroke="rgba(255, 255, 255, 0.2)"
              strokeWidth="1"
            />
          );
        })}
      </svg>
      
      {/* Progress percentage text - removed to avoid overlap */}
    </div>
  );
}