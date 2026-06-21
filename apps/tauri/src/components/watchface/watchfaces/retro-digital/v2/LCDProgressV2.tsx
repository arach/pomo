import React from 'react';

interface LCDProgressV2Props {
  progress: number;
  style?: React.CSSProperties;
}

export function LCDProgressV2({ progress, style }: LCDProgressV2Props) {
  const segments = 20;
  const filledSegments = Math.floor((progress / 100) * segments);
  
  return (
    <div style={{
      ...style,
      position: 'relative',
      padding: '15px',
      background: 'linear-gradient(145deg, #1a1a1a, #0f0f0f)',
      borderRadius: '8px',
      boxShadow: 'inset 0 2px 8px rgba(0,0,0,0.8), 0 1px 2px rgba(255,255,255,0.1)',
      border: '1px solid #333'
    }}>
      {/* V2 indicator */}
      <div style={{
        position: 'absolute',
        top: -10,
        right: 10,
        background: 'linear-gradient(45deg, #00ff00, #00cc00)',
        color: '#000',
        padding: '2px 6px',
        borderRadius: '4px',
        fontSize: '8px',
        fontWeight: 'bold',
        boxShadow: '0 0 10px rgba(0, 255, 0, 0.5)',
        fontFamily: 'monospace'
      }}>
        V2
      </div>
      
      {/* LCD Display background */}
      <div style={{
        background: 'linear-gradient(to bottom, #2a3a2a, #1a2a1a)',
        padding: '10px',
        borderRadius: '4px',
        boxShadow: 'inset 0 2px 4px rgba(0,0,0,0.6)',
        position: 'relative',
        overflow: 'hidden'
      }}>
        {/* LCD grid effect */}
        <div style={{
          position: 'absolute',
          inset: 0,
          backgroundImage: `
            repeating-linear-gradient(0deg, transparent, transparent 2px, rgba(0,0,0,0.1) 2px, rgba(0,0,0,0.1) 3px),
            repeating-linear-gradient(90deg, transparent, transparent 2px, rgba(0,0,0,0.1) 2px, rgba(0,0,0,0.1) 3px)
          `,
          pointerEvents: 'none'
        }} />
        
        {/* Progress segments */}
        <div style={{
          display: 'flex',
          gap: '2px',
          position: 'relative',
          zIndex: 1
        }}>
          {Array.from({ length: segments }).map((_, i) => {
            const isFilled = i < filledSegments;
            const isEdge = i === filledSegments - 1;
            
            return (
              <div
                key={i}
                style={{
                  width: '12px',
                  height: '24px',
                  background: isFilled 
                    ? 'linear-gradient(to bottom, #00ff00, #00cc00)' 
                    : 'linear-gradient(to bottom, #1a2a1a, #0f1f0f)',
                  boxShadow: isFilled 
                    ? 'inset 0 1px 2px rgba(0,0,0,0.3), 0 0 8px rgba(0,255,0,0.6)' 
                    : 'inset 0 1px 2px rgba(0,0,0,0.5)',
                  opacity: isFilled ? 1 : 0.3,
                  transition: 'all 0.3s ease',
                  transform: isEdge && isFilled ? 'scale(1.1)' : 'scale(1)',
                  filter: isFilled ? 'brightness(1.2)' : 'brightness(0.8)',
                  borderRadius: '1px'
                }}
              />
            );
          })}
        </div>
        
        {/* Percentage display */}
        <div style={{
          marginTop: '8px',
          display: 'flex',
          justifyContent: 'center',
          alignItems: 'center',
          gap: '4px'
        }}>
          {/* 7-segment style digits */}
          <div style={{
            fontFamily: "'DSEG7 Classic', 'LCD', monospace",
            fontSize: '18px',
            color: '#00ff00',
            textShadow: '0 0 10px rgba(0, 255, 0, 0.8), 0 0 20px rgba(0, 255, 0, 0.4)',
            letterSpacing: '2px',
            background: 'linear-gradient(to bottom, rgba(0,0,0,0.3), transparent)',
            padding: '2px 6px',
            borderRadius: '2px',
            position: 'relative'
          }}>
            {/* Ghost segments */}
            <span style={{
              position: 'absolute',
              left: '6px',
              opacity: 0.1,
              color: '#00ff00',
              filter: 'blur(0.5px)'
            }}>888</span>
            <span style={{ position: 'relative', zIndex: 1 }}>
              {Math.round(progress).toString().padStart(3, ' ')}
            </span>
          </div>
          <span style={{
            color: '#00ff00',
            fontSize: '14px',
            textShadow: '0 0 8px rgba(0, 255, 0, 0.6)',
            opacity: 0.9
          }}>%</span>
        </div>
      </div>
      
      {/* Bottom labels */}
      <div style={{
        display: 'flex',
        justifyContent: 'space-between',
        marginTop: '6px',
        fontSize: '8px',
        color: '#666',
        fontFamily: 'monospace',
        textTransform: 'uppercase',
        letterSpacing: '0.5px'
      }}>
        <span>Empty</span>
        <span style={{ color: '#00ff00', textShadow: '0 0 4px rgba(0,255,0,0.5)' }}>
          Power Level
        </span>
        <span>Full</span>
      </div>
    </div>
  );
}