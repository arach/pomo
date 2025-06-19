import React, { useEffect, useState } from 'react';

interface DigitalDisplayV2Props {
  value: string;
  style?: React.CSSProperties;
}

interface SegmentProps {
  on: boolean;
  type: 'horizontal' | 'vertical';
  position: string;
  flicker?: boolean;
}

const Segment: React.FC<SegmentProps> = ({ on, type, position, flicker }) => {
  const baseStyle: React.CSSProperties = {
    position: 'absolute',
    background: on 
      ? 'linear-gradient(45deg, #ff6600, #ffcc00)' 
      : 'rgba(50, 40, 30, 0.2)',
    transition: 'all 0.15s cubic-bezier(0.4, 0, 0.2, 1)',
    boxShadow: on 
      ? '0 0 15px #ff8800, 0 0 30px rgba(255, 136, 0, 0.5), inset 0 0 3px rgba(255,255,255,0.7)' 
      : 'inset 0 0 3px rgba(0,0,0,0.3)',
    filter: on ? 'brightness(1.3) contrast(1.2)' : 'brightness(0.3)',
    opacity: flicker && on ? 0.85 : 1,
    transform: on ? 'scale(1.02)' : 'scale(1)'
  };

  const horizontalStyle: React.CSSProperties = {
    ...baseStyle,
    width: '18px',
    height: '4px',
    clipPath: 'polygon(20% 0%, 80% 0%, 100% 50%, 80% 100%, 20% 100%, 0% 50%)'
  };

  const verticalStyle: React.CSSProperties = {
    ...baseStyle,
    width: '4px',
    height: '22px',
    clipPath: 'polygon(0% 20%, 50% 0%, 100% 20%, 100% 80%, 50% 100%, 0% 80%)'
  };

  const positions: Record<string, React.CSSProperties> = {
    top: { top: 0, left: '3px' },
    middle: { top: '23px', left: '3px' },
    bottom: { top: '46px', left: '3px' },
    topLeft: { top: '2px', left: '1px' },
    topRight: { top: '2px', right: '1px' },
    bottomLeft: { top: '25px', left: '1px' },
    bottomRight: { top: '25px', right: '1px' }
  };

  return (
    <div style={{
      ...(type === 'horizontal' ? horizontalStyle : verticalStyle),
      ...positions[position]
    }} />
  );
};

const SevenSegmentDigit: React.FC<{ digit: string; flicker?: boolean }> = ({ digit, flicker }) => {
  const segments: Record<string, boolean[]> = {
    '0': [true, true, true, false, true, true, true],
    '1': [false, false, true, false, false, true, false],
    '2': [true, false, true, true, true, false, true],
    '3': [true, false, true, true, false, true, true],
    '4': [false, true, true, true, false, true, false],
    '5': [true, true, false, true, false, true, true],
    '6': [true, true, false, true, true, true, true],
    '7': [true, false, true, false, false, true, false],
    '8': [true, true, true, true, true, true, true],
    '9': [true, true, true, true, false, true, true],
    ':': [false, false, false, false, false, false, false],
    ' ': [false, false, false, false, false, false, false]
  };

  const segmentMap = segments[digit] || segments[' '];

  return (
    <div style={{
      position: 'relative',
      width: '26px',
      height: '50px',
      margin: '0 3px',
      display: 'inline-block',
      background: 'rgba(20, 15, 10, 0.5)',
      borderRadius: '4px',
      boxShadow: 'inset 0 2px 4px rgba(0,0,0,0.4)',
      padding: '2px'
    }}>
      {/* Ghost segments for LCD effect */}
      <div style={{
        position: 'absolute',
        inset: '2px',
        opacity: 0.05,
        filter: 'blur(0.5px)'
      }}>
        <Segment on={true} type="horizontal" position="top" />
        <Segment on={true} type="vertical" position="topLeft" />
        <Segment on={true} type="vertical" position="topRight" />
        <Segment on={true} type="horizontal" position="middle" />
        <Segment on={true} type="vertical" position="bottomLeft" />
        <Segment on={true} type="vertical" position="bottomRight" />
        <Segment on={true} type="horizontal" position="bottom" />
      </div>
      
      {/* Active segments */}
      <Segment on={segmentMap[0]} type="horizontal" position="top" flicker={flicker} />
      <Segment on={segmentMap[1]} type="vertical" position="topLeft" flicker={flicker} />
      <Segment on={segmentMap[2]} type="vertical" position="topRight" flicker={flicker} />
      <Segment on={segmentMap[3]} type="horizontal" position="middle" flicker={flicker} />
      <Segment on={segmentMap[4]} type="vertical" position="bottomLeft" flicker={flicker} />
      <Segment on={segmentMap[5]} type="vertical" position="bottomRight" flicker={flicker} />
      <Segment on={segmentMap[6]} type="horizontal" position="bottom" flicker={flicker} />
      
      {digit === ':' && (
        <>
          <div style={{
            position: 'absolute',
            width: '6px',
            height: '6px',
            borderRadius: '50%',
            background: 'linear-gradient(45deg, #ff6600, #ffcc00)',
            boxShadow: '0 0 15px #ff8800, 0 0 25px rgba(255, 136, 0, 0.6)',
            top: '13px',
            left: '10px',
            animation: 'colonBlink 1s ease-in-out infinite'
          }} />
          <div style={{
            position: 'absolute',
            width: '6px',
            height: '6px',
            borderRadius: '50%',
            background: 'linear-gradient(45deg, #ff6600, #ffcc00)',
            boxShadow: '0 0 15px #ff8800, 0 0 25px rgba(255, 136, 0, 0.6)',
            bottom: '13px',
            left: '10px',
            animation: 'colonBlink 1s ease-in-out infinite 0.5s'
          }} />
        </>
      )}
    </div>
  );
};

export function DigitalDisplayV2({ value, style }: DigitalDisplayV2Props) {
  const [flicker, setFlicker] = useState(false);
  const [scanline, setScanline] = useState(0);

  useEffect(() => {
    const flickerInterval = setInterval(() => {
      if (Math.random() > 0.95) {
        setFlicker(true);
        setTimeout(() => setFlicker(false), 100);
      }
    }, 1000);
    return () => clearInterval(flickerInterval);
  }, []);

  useEffect(() => {
    const scanlineInterval = setInterval(() => {
      setScanline(prev => (prev + 1) % 100);
    }, 50);
    return () => clearInterval(scanlineInterval);
  }, []);

  return (
    <div style={{
      ...style,
      position: 'relative',
      display: 'inline-block',
      padding: '15px',
      background: 'linear-gradient(145deg, #1a1612, #0f0d0a)',
      borderRadius: '8px',
      boxShadow: 'inset 0 4px 8px rgba(0,0,0,0.6), 0 2px 4px rgba(255,136,0,0.2)',
      border: '2px solid #332922'
    }}>
      {/* V2 indicator */}
      <div style={{
        position: 'absolute',
        top: -8,
        right: 10,
        background: 'linear-gradient(45deg, #ff6600, #ffcc00)',
        color: '#000',
        padding: '2px 6px',
        borderRadius: '10px',
        fontSize: '8px',
        fontWeight: 'bold',
        boxShadow: '0 0 10px rgba(255, 136, 0, 0.6)',
        fontFamily: 'monospace',
        animation: 'v2glow 2s ease-in-out infinite'
      }}>
        V2.0
      </div>
      
      {/* Display container */}
      <div style={{
        display: 'flex',
        justifyContent: 'center',
        alignItems: 'center',
        position: 'relative',
        filter: flicker ? 'brightness(0.9)' : 'brightness(1)',
        animation: 'displayGlow 3s ease-in-out infinite'
      }}>
        {/* Scanline effect */}
        <div style={{
          position: 'absolute',
          top: `${scanline}%`,
          left: 0,
          right: 0,
          height: '2px',
          background: 'linear-gradient(to right, transparent, rgba(255, 136, 0, 0.1), transparent)',
          pointerEvents: 'none',
          opacity: 0.5
        }} />
        
        {value.split('').map((char, index) => (
          <SevenSegmentDigit key={index} digit={char} flicker={flicker} />
        ))}
      </div>
      
      {/* Additional indicators */}
      <div style={{
        display: 'flex',
        justifyContent: 'space-between',
        marginTop: '8px',
        fontSize: '8px',
        color: '#ff8800',
        textTransform: 'uppercase',
        fontFamily: 'monospace',
        opacity: 0.7
      }}>
        <span style={{ 
          textShadow: '0 0 5px currentColor',
          animation: 'indicatorPulse 2s ease-in-out infinite'
        }}>PM</span>
        <span style={{ color: '#666' }}>CHRONO</span>
        <span style={{ 
          color: flicker ? '#ff4444' : '#44ff44',
          textShadow: `0 0 5px ${flicker ? '#ff4444' : '#44ff44'}`
        }}>RUN</span>
      </div>
      
      <style>{`
        @keyframes colonBlink {
          0%, 100% { opacity: 1; transform: scale(1); }
          50% { opacity: 0.7; transform: scale(0.9); }
        }
        @keyframes v2glow {
          0%, 100% { opacity: 1; box-shadow: 0 0 10px rgba(255, 136, 0, 0.6); }
          50% { opacity: 0.9; box-shadow: 0 0 15px rgba(255, 136, 0, 0.8); }
        }
        @keyframes displayGlow {
          0%, 100% { filter: brightness(1) contrast(1); }
          50% { filter: brightness(1.05) contrast(1.1); }
        }
        @keyframes indicatorPulse {
          0%, 100% { opacity: 0.7; }
          50% { opacity: 1; }
        }
      `}</style>
    </div>
  );
}