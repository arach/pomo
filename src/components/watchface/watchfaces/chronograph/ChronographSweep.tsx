import React from 'react';

interface ChronographSweepProps {
  progress: number;
  style?: React.CSSProperties;
}

export function ChronographSweep({ progress, style }: ChronographSweepProps) {
  const radius = 110;
  const centerX = 120;
  const centerY = 120;
  
  // Calculate angle for sweep hand (-90deg = 12 o'clock start position)
  const angle = -90 + (progress * 3.6); // 360deg / 100 = 3.6deg per percent
  const angleRad = (angle * Math.PI) / 180;
  
  // Calculate hand end position
  const handLength = radius - 15;
  const handX = centerX + handLength * Math.cos(angleRad);
  const handY = centerY + handLength * Math.sin(angleRad);
  
  // Calculate tail position (opposite direction, shorter)
  const tailLength = 20;
  const tailX = centerX - tailLength * Math.cos(angleRad);
  const tailY = centerY - tailLength * Math.sin(angleRad);
  
  return (
    <div style={{
      ...style,
      position: 'absolute',
      top: '50%',
      left: '50%',
      transform: 'translate(-50%, -50%)',
      width: '240px',
      height: '240px'
    }}>
      <svg width="240" height="240" style={{ position: 'absolute' }}>
        {/* Progress arc trail */}
        <circle
          cx={centerX}
          cy={centerY}
          r={radius}
          fill="none"
          stroke="rgba(255, 255, 255, 0.05)"
          strokeWidth="1"
        />
        
        {/* Progress arc */}
        <path
          d={describeArc(centerX, centerY, radius, -90, -90 + (progress * 3.6))}
          fill="none"
          stroke="rgba(59, 130, 246, 0.3)"
          strokeWidth="2"
        />
        
        {/* Center jewel */}
        <circle
          cx={centerX}
          cy={centerY}
          r="8"
          fill="#1e293b"
          stroke="#3b82f6"
          strokeWidth="2"
        />
        
        {/* Sweep hand shadow */}
        <line
          x1={tailX}
          y1={tailY}
          x2={handX}
          y2={handY}
          stroke="rgba(0, 0, 0, 0.3)"
          strokeWidth="3"
          strokeLinecap="round"
          transform="translate(2, 2)"
        />
        
        {/* Sweep hand */}
        <line
          x1={tailX}
          y1={tailY}
          x2={handX}
          y2={handY}
          stroke="#3b82f6"
          strokeWidth="3"
          strokeLinecap="round"
          style={{
            filter: 'drop-shadow(0 0 3px rgba(59, 130, 246, 0.5))',
            transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)'
          }}
        />
        
        {/* Sweep hand tip */}
        <circle
          cx={handX}
          cy={handY}
          r="4"
          fill="#3b82f6"
          style={{
            filter: 'drop-shadow(0 0 5px rgba(59, 130, 246, 0.8))'
          }}
        />
        
        {/* Center cap */}
        <circle
          cx={centerX}
          cy={centerY}
          r="5"
          fill="#3b82f6"
        />
      </svg>
      
      {/* Progress percentage */}
      <div style={{
        position: 'absolute',
        bottom: '60px',
        left: '50%',
        transform: 'translateX(-50%)',
        fontSize: '14px',
        fontWeight: '500',
        color: '#64748b',
        fontFamily: "'Inter', sans-serif",
        letterSpacing: '0.05em'
      }}>
        {Math.round(progress)}%
      </div>
    </div>
  );
}

// Helper function to create SVG arc path
function describeArc(x: number, y: number, radius: number, startAngle: number, endAngle: number) {
  const start = polarToCartesian(x, y, radius, endAngle);
  const end = polarToCartesian(x, y, radius, startAngle);
  const largeArcFlag = endAngle - startAngle <= 180 ? "0" : "1";
  
  return [
    "M", start.x, start.y,
    "A", radius, radius, 0, largeArcFlag, 0, end.x, end.y
  ].join(" ");
}

function polarToCartesian(centerX: number, centerY: number, radius: number, angleInDegrees: number) {
  const angleInRadians = (angleInDegrees - 90) * Math.PI / 180.0;
  return {
    x: centerX + (radius * Math.cos(angleInRadians)),
    y: centerY + (radius * Math.sin(angleInRadians))
  };
}