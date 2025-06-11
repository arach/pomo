import React, { useEffect, useState } from 'react';

interface DigitalDisplayProps {
  value: string;
  style?: React.CSSProperties;
}

interface SegmentProps {
  on: boolean;
  type: 'horizontal' | 'vertical';
  position: string;
}

const Segment: React.FC<SegmentProps> = ({ on, type, position }) => {
  const baseStyle: React.CSSProperties = {
    position: 'absolute',
    background: on ? '#ffcc00' : 'rgba(50, 40, 30, 0.3)',
    transition: 'all 0.1s',
    boxShadow: on ? '0 0 10px #ffcc00, inset 0 0 3px rgba(255,255,255,0.5)' : 'inset 0 0 3px rgba(0,0,0,0.5)',
    filter: on ? 'brightness(1.2)' : 'brightness(0.5)'
  };

  const horizontalStyle: React.CSSProperties = {
    ...baseStyle,
    width: '16px',
    height: '3px',
    clipPath: 'polygon(15% 0%, 85% 0%, 100% 50%, 85% 100%, 15% 100%, 0% 50%)'
  };

  const verticalStyle: React.CSSProperties = {
    ...baseStyle,
    width: '3px',
    height: '20px',
    clipPath: 'polygon(0% 15%, 50% 0%, 100% 15%, 100% 85%, 50% 100%, 0% 85%)'
  };

  const positions: Record<string, React.CSSProperties> = {
    top: { top: 0, left: '3px' },
    middle: { top: '21px', left: '3px' },
    bottom: { top: '42px', left: '3px' },
    topLeft: { top: '2px', left: '1px' },
    topRight: { top: '2px', right: '1px' },
    bottomLeft: { top: '23px', left: '1px' },
    bottomRight: { top: '23px', right: '1px' }
  };

  return (
    <div style={{
      ...(type === 'horizontal' ? horizontalStyle : verticalStyle),
      ...positions[position]
    }} />
  );
};

const SevenSegmentDigit: React.FC<{ digit: string }> = ({ digit }) => {
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
      width: '24px',
      height: '45px',
      margin: '0 2px',
      display: 'inline-block'
    }}>
      <Segment on={segmentMap[0]} type="horizontal" position="top" />
      <Segment on={segmentMap[1]} type="vertical" position="topLeft" />
      <Segment on={segmentMap[2]} type="vertical" position="topRight" />
      <Segment on={segmentMap[3]} type="horizontal" position="middle" />
      <Segment on={segmentMap[4]} type="vertical" position="bottomLeft" />
      <Segment on={segmentMap[5]} type="vertical" position="bottomRight" />
      <Segment on={segmentMap[6]} type="horizontal" position="bottom" />
      
      {digit === ':' && (
        <>
          <div style={{
            position: 'absolute',
            width: '5px',
            height: '5px',
            borderRadius: '50%',
            background: '#ffcc00',
            boxShadow: '0 0 10px #ffcc00',
            top: '12px',
            left: '9px'
          }} />
          <div style={{
            position: 'absolute',
            width: '5px',
            height: '5px',
            borderRadius: '50%',
            background: '#ffcc00',
            boxShadow: '0 0 10px #ffcc00',
            bottom: '12px',
            left: '9px'
          }} />
        </>
      )}
    </div>
  );
};

export function DigitalDisplay({ value, style }: DigitalDisplayProps) {
  const [flicker, setFlicker] = useState(false);

  useEffect(() => {
    const interval = setInterval(() => {
      setFlicker(prev => !prev);
    }, 3000 + Math.random() * 2000);
    return () => clearInterval(interval);
  }, []);

  return (
    <div style={{
      ...style,
      display: 'flex',
      justifyContent: 'center',
      alignItems: 'center',
      animation: flicker ? 'digitFlicker 0.1s' : 'glowPulse 2s ease-in-out infinite'
    }}>
      {value.split('').map((char, index) => (
        <SevenSegmentDigit key={index} digit={char} />
      ))}
    </div>
  );
}