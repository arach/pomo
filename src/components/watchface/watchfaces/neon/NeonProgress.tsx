import React, { useEffect, useState } from 'react';

interface NeonProgressProps {
  progress: number;
  style?: React.CSSProperties;
}

export function NeonProgress({ progress, style }: NeonProgressProps) {
  const [pulse, setPulse] = useState(0);
  
  useEffect(() => {
    const interval = setInterval(() => {
      setPulse(prev => (prev + 1) % 3);
    }, 2000);
    return () => clearInterval(interval);
  }, []);

  const radius = 120;
  const strokeWidth = 3;
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
      {/* Outer glow ring */}
      <svg
        width={radius * 2}
        height={radius * 2}
        style={{
          position: 'absolute',
          top: 0,
          left: 0,
          transform: 'rotate(-90deg)',
          filter: 'blur(8px)',
          opacity: 0.6
        }}
      >
        <circle
          stroke="#ff00ff"
          fill="none"
          strokeWidth={strokeWidth + 2}
          strokeDasharray={circumference + ' ' + circumference}
          strokeDashoffset={strokeDashoffset}
          r={normalizedRadius}
          cx={radius}
          cy={radius}
          style={{
            transition: 'stroke-dashoffset 0.5s ease-out',
            strokeLinecap: 'round'
          }}
        />
      </svg>

      {/* Main progress ring */}
      <svg
        width={radius * 2}
        height={radius * 2}
        style={{
          position: 'relative',
          transform: 'rotate(-90deg)'
        }}
      >
        {/* Background track */}
        <circle
          stroke="rgba(255, 0, 255, 0.1)"
          fill="none"
          strokeWidth={strokeWidth}
          r={normalizedRadius}
          cx={radius}
          cy={radius}
        />
        
        {/* Progress stroke */}
        <circle
          stroke="url(#neonGradient)"
          fill="none"
          strokeWidth={strokeWidth}
          strokeDasharray={circumference + ' ' + circumference}
          strokeDashoffset={strokeDashoffset}
          r={normalizedRadius}
          cx={radius}
          cy={radius}
          style={{
            transition: 'stroke-dashoffset 0.5s ease-out',
            strokeLinecap: 'round',
            filter: `drop-shadow(0 0 ${6 + pulse * 2}px #ff00ff) drop-shadow(0 0 ${12 + pulse * 4}px #00ffff)`
          }}
        />
        
        {/* Gradient definition */}
        <defs>
          <linearGradient id="neonGradient" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" stopColor="#ff00ff" />
            <stop offset="50%" stopColor="#00ffff" />
            <stop offset="100%" stopColor="#ff00ff" />
          </linearGradient>
        </defs>
      </svg>
      
      {/* Progress percentage */}
      <div style={{
        position: 'absolute',
        top: '50%',
        left: '50%',
        transform: 'translate(-50%, -50%)',
        fontSize: '32px',
        fontWeight: '100',
        fontFamily: 'monospace',
        color: '#00ffff',
        textShadow: `0 0 10px #00ffff, 0 0 20px #ff00ff`,
        letterSpacing: '0.1em',
        opacity: 0.9
      }}>
        {Math.round(progress)}%
      </div>
      
      {/* Energy particles */}
      {progress > 0 && (
        <div style={{
          position: 'absolute',
          top: '50%',
          left: '50%',
          width: radius * 2,
          height: radius * 2,
          transform: 'translate(-50%, -50%)',
          pointerEvents: 'none'
        }}>
          {[...Array(3)].map((_, i) => (
            <div
              key={i}
              style={{
                position: 'absolute',
                width: '4px',
                height: '4px',
                background: i % 2 === 0 ? '#ff00ff' : '#00ffff',
                borderRadius: '50%',
                boxShadow: `0 0 6px currentColor`,
                top: '50%',
                left: '50%',
                transform: `rotate(${(progress * 3.6) + (i * 120)}deg) translate(${normalizedRadius}px) translate(-50%, -50%)`,
                animation: `neonPulse ${1.5 + i * 0.3}s ease-in-out infinite`
              }}
            />
          ))}
        </div>
      )}
      
      <style dangerouslySetInnerHTML={{ __html: `
        @keyframes neonPulse {
          0%, 100% { opacity: 0.3; transform: scale(0.8); }
          50% { opacity: 1; transform: scale(1.2); }
        }
      `}} />
    </div>
  );
}