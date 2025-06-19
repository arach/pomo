import React, { useState, useEffect } from 'react';

interface NeonProgressV2Props {
  progress: number;
  style?: React.CSSProperties;
}

export function NeonProgressV2({ progress, style }: NeonProgressV2Props) {
  const [particles, setParticles] = useState<Array<{ id: number; angle: number; distance: number; opacity: number }>>([]);
  const size = 200;
  const center = size / 2;
  const strokeWidth = 4;
  const radius = 85;
  const circumference = radius * 2 * Math.PI;
  const strokeDashoffset = circumference - (progress / 100) * circumference;
  
  // Calculate progress position for end cap
  const angle = (progress / 100) * 2 * Math.PI - Math.PI / 2;
  const endX = center + radius * Math.cos(angle);
  const endY = center + radius * Math.sin(angle);
  
  // Generate particles for atmospheric effect
  useEffect(() => {
    const newParticles = Array.from({ length: 20 }, (_, i) => ({
      id: i,
      angle: Math.random() * Math.PI * 2,
      distance: radius + Math.random() * 30,
      opacity: Math.random() * 0.5
    }));
    setParticles(newParticles);
  }, []);
  
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
      {/* V2 indicator badge */}
      <div style={{
        position: 'absolute',
        top: -10,
        right: -10,
        background: 'linear-gradient(45deg, #ff00ff, #00ffff)',
        color: '#fff',
        padding: '2px 8px',
        borderRadius: '12px',
        fontSize: '10px',
        fontWeight: 'bold',
        zIndex: 100,
        boxShadow: '0 0 10px rgba(255, 0, 255, 0.8)'
      }}>
        V2
      </div>
      {/* Enhanced outer glow with animation */}
      <div
        style={{
          position: 'absolute',
          width: size + 40,
          height: size + 40,
          borderRadius: '50%',
          background: `radial-gradient(circle at center, 
            transparent 60%, 
            rgba(255, 0, 255, 0.1) 70%, 
            rgba(0, 255, 255, 0.1) 80%, 
            rgba(255, 0, 255, 0.05) 90%,
            transparent 100%)`,
          filter: 'blur(20px)',
          animation: 'neonPulse 4s ease-in-out infinite'
        }}
      />
      
      {/* Atmospheric particles */}
      <svg
        width={size}
        height={size}
        style={{
          position: 'absolute',
          pointerEvents: 'none'
        }}
      >
        {particles.map((particle) => {
          const x = center + particle.distance * Math.cos(particle.angle);
          const y = center + particle.distance * Math.sin(particle.angle);
          return (
            <circle
              key={particle.id}
              cx={x}
              cy={y}
              r="1"
              fill="#fff"
              opacity={particle.opacity}
              style={{
                animation: `particleFloat ${10 + particle.id * 0.5}s linear infinite`
              }}
            />
          );
        })}
      </svg>
      
      {/* Main progress ring */}
      <svg
        width={size}
        height={size}
        style={{
          position: 'absolute',
          transform: 'rotate(-90deg)'
        }}
      >
        {/* Background track with subtle pattern */}
        <circle
          stroke="url(#trackPattern)"
          fill="none"
          strokeWidth={strokeWidth}
          r={radius}
          cx={center}
          cy={center}
          opacity="0.3"
        />
        
        {/* Multiple glow layers for depth */}
        <circle
          stroke="rgba(255, 0, 255, 0.2)"
          fill="none"
          strokeWidth={strokeWidth + 8}
          r={radius}
          cx={center}
          cy={center}
          strokeDasharray={circumference + ' ' + circumference}
          strokeDashoffset={strokeDashoffset}
          style={{
            transition: 'stroke-dashoffset 0.5s ease-out',
            filter: 'blur(8px)'
          }}
        />
        
        <circle
          stroke="url(#neonGradientV2)"
          fill="none"
          strokeWidth={strokeWidth + 4}
          strokeDasharray={circumference + ' ' + circumference}
          strokeDashoffset={strokeDashoffset}
          r={radius}
          cx={center}
          cy={center}
          opacity="0.6"
          style={{
            transition: 'stroke-dashoffset 0.5s ease-out',
            strokeLinecap: 'round',
            filter: 'blur(4px)'
          }}
        />
        
        {/* Main progress stroke */}
        <circle
          stroke="url(#neonGradientV2)"
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
            filter: 'drop-shadow(0 0 4px rgba(255, 0, 255, 1))'
          }}
        />
        
        {/* Electric effect along the progress */}
        {progress > 0 && progress < 100 && (
          <g transform={`rotate(90 ${center} ${center})`}>
            {/* Enhanced end cap with multiple layers */}
            <circle
              fill="rgba(255, 255, 255, 0.3)"
              r={strokeWidth + 6}
              cx={endX}
              cy={endY}
              style={{
                filter: 'blur(6px)',
                animation: 'endCapPulse 2s ease-in-out infinite'
              }}
            />
            <circle
              fill="url(#neonGradientV2)"
              r={strokeWidth + 2}
              cx={endX}
              cy={endY}
              opacity="0.8"
              style={{
                filter: 'blur(2px)'
              }}
            />
            <circle
              fill="#fff"
              r={strokeWidth / 2}
              cx={endX}
              cy={endY}
              style={{
                filter: 'drop-shadow(0 0 8px rgba(255, 255, 255, 1))'
              }}
            />
          </g>
        )}
        
        {/* Enhanced gradient definitions */}
        <defs>
          <linearGradient 
            id="neonGradientV2" 
            x1="0%" 
            y1="0%" 
            x2="100%" 
            y2="100%"
          >
            <stop offset="0%" stopColor="#ff00ff" stopOpacity="1">
              <animate attributeName="stopColor" values="#ff00ff;#ff00cc;#ff00ff" dur="3s" repeatCount="indefinite" />
            </stop>
            <stop offset="33%" stopColor="#ff00cc" stopOpacity="1" />
            <stop offset="66%" stopColor="#00ffff" stopOpacity="1">
              <animate attributeName="stopColor" values="#00ffff;#00ccff;#00ffff" dur="3s" repeatCount="indefinite" />
            </stop>
            <stop offset="100%" stopColor="#ff00ff" stopOpacity="1" />
          </linearGradient>
          
          <pattern id="trackPattern" x="0" y="0" width="10" height="10" patternUnits="userSpaceOnUse">
            <rect width="10" height="10" fill="transparent" />
            <circle cx="5" cy="5" r="0.5" fill="rgba(255, 255, 255, 0.3)" />
          </pattern>
          
          <filter id="neonGlow">
            <feGaussianBlur stdDeviation="3" result="coloredBlur"/>
            <feMerge>
              <feMergeNode in="coloredBlur"/>
              <feMergeNode in="SourceGraphic"/>
            </feMerge>
          </filter>
        </defs>
      </svg>
      
      {/* Enhanced tick marks with glow */}
      <svg
        width={size}
        height={size}
        style={{
          position: 'absolute',
          pointerEvents: 'none'
        }}
      >
        {[...Array(12)].map((_, i) => {
          const tickAngle = (i * 30) * Math.PI / 180;
          const isActive = (i * 30) <= (progress * 3.6);
          const x1 = center + (radius - 12) * Math.cos(tickAngle);
          const y1 = center + (radius - 12) * Math.sin(tickAngle);
          const x2 = center + (radius - 6) * Math.cos(tickAngle);
          const y2 = center + (radius - 6) * Math.sin(tickAngle);
          
          return (
            <g key={i}>
              {isActive && (
                <line
                  x1={x1}
                  y1={y1}
                  x2={x2}
                  y2={y2}
                  stroke="rgba(255, 0, 255, 0.5)"
                  strokeWidth="3"
                  style={{ filter: 'blur(2px)' }}
                />
              )}
              <line
                x1={x1}
                y1={y1}
                x2={x2}
                y2={y2}
                stroke={isActive ? '#ff00ff' : 'rgba(255, 255, 255, 0.2)'}
                strokeWidth="1.5"
                style={{
                  transition: 'all 0.3s ease',
                  filter: isActive ? 'drop-shadow(0 0 2px #ff00ff)' : 'none'
                }}
              />
            </g>
          );
        })}
      </svg>
      
      {/* CSS animations */}
      <style>{`
        @keyframes neonPulse {
          0%, 100% { transform: scale(1); opacity: 0.6; }
          50% { transform: scale(1.05); opacity: 0.8; }
        }
        
        @keyframes endCapPulse {
          0%, 100% { transform: scale(1); opacity: 0.8; }
          50% { transform: scale(1.2); opacity: 1; }
        }
        
        @keyframes particleFloat {
          0% { transform: translateY(0) translateX(0); opacity: 0; }
          10% { opacity: 0.5; }
          90% { opacity: 0.5; }
          100% { transform: translateY(-20px) translateX(10px); opacity: 0; }
        }
      `}</style>
    </div>
  );
}