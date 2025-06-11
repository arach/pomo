import React, { useEffect, useState } from 'react';

interface MinimalProgressProps {
  progress: number;
  style?: React.CSSProperties;
}

export function MinimalProgress({ progress, style }: MinimalProgressProps) {
  const [visible, setVisible] = useState(false);
  
  useEffect(() => {
    const timer = setTimeout(() => setVisible(true), 100);
    return () => clearTimeout(timer);
  }, []);

  return (
    <div style={{ 
      ...style, 
      position: 'relative', 
      overflow: 'hidden',
      opacity: visible ? 1 : 0,
      transform: visible ? 'scaleX(1)' : 'scaleX(0.95)',
      transition: 'all 0.6s cubic-bezier(0.4, 0, 0.2, 1)',
      transformOrigin: 'left center'
    }}>
      {/* Background track */}
      <div
        style={{
          position: 'absolute',
          top: 0,
          left: 0,
          right: 0,
          height: '100%',
          background: 'currentColor',
          opacity: 0.1,
          borderRadius: 'inherit'
        }}
      />
      
      {/* Progress fill */}
      <div
        style={{
          position: 'absolute',
          top: 0,
          left: 0,
          height: '100%',
          width: `${progress}%`,
          background: 'currentColor',
          transition: 'width 0.8s cubic-bezier(0.4, 0, 0.2, 1)',
          borderRadius: 'inherit',
          boxShadow: '0 0 10px currentColor',
          opacity: 0.9
        }}
      >
        {/* Shimmer effect */}
        <div
          style={{
            position: 'absolute',
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            background: 'linear-gradient(90deg, transparent 0%, rgba(255,255,255,0.3) 50%, transparent 100%)',
            transform: 'translateX(-100%)',
            animation: 'shimmer 2s infinite'
          }}
        />
      </div>
      
      {/* Progress tip glow */}
      {progress > 0 && progress < 100 && (
        <div
          style={{
            position: 'absolute',
            top: '50%',
            left: `${progress}%`,
            transform: 'translate(-50%, -50%)',
            width: '20px',
            height: '20px',
            background: 'radial-gradient(circle, currentColor 0%, transparent 70%)',
            opacity: 0.6,
            filter: 'blur(4px)',
            animation: 'pulse 2s ease-in-out infinite'
          }}
        />
      )}
      
      <style dangerouslySetInnerHTML={{ __html: `
        @keyframes shimmer {
          to { transform: translateX(100%); }
        }
      `}} />
    </div>
  );
}