import { useEffect, useState } from 'react';

interface RolodexDisplayProps {
  remaining: number;
  isRunning: boolean;
  onTimeClick?: () => void;
}

interface DigitProps {
  value: string;
}

function RolodexDigit({ value }: DigitProps) {
  const [displayValue, setDisplayValue] = useState(value);
  
  useEffect(() => {
    setDisplayValue(value);
  }, [value]);
  
  return (
    <div style={{
      position: 'relative',
      width: '56px',
      height: '84px',
      fontSize: '68px',
      fontFamily: "'Bebas Neue', sans-serif",
      color: '#f0f0f0',
      background: '#2a2a2a',
      borderRadius: '8px',
      boxShadow: '0 4px 8px rgba(0,0,0,0.3)',
      overflow: 'hidden',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center'
    }}>
      <div style={{
        transition: 'opacity 0.15s ease-out',
        opacity: 1
      }}>
        {displayValue}
      </div>
      
      {/* Center line */}
      <div style={{
        position: 'absolute',
        width: '100%',
        height: '1px',
        top: '50%',
        background: 'rgba(0,0,0,0.5)',
        zIndex: 1
      }} />
    </div>
  );
}

export function RolodexDisplay({ remaining, isRunning, onTimeClick }: RolodexDisplayProps) {
  const formatDigits = (num: number) => num.toString().padStart(2, '0').split('');
  
  const minutes = Math.floor(remaining / 60);
  const seconds = remaining % 60;
  
  const [m1, m2] = formatDigits(minutes);
  const [s1, s2] = formatDigits(seconds);
  
  return (
    <div style={{
      width: '100%',
      height: '100%',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center'
    }}>
      <div 
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          gap: '4px',
          cursor: !isRunning && onTimeClick ? 'pointer' : 'default'
        }}
        onClick={() => !isRunning && onTimeClick && onTimeClick()}
      >
        <RolodexDigit value={m1} />
        <RolodexDigit value={m2} />
        
        <div style={{
          fontSize: '48px',
          fontFamily: "'Bebas Neue', sans-serif",
          color: '#ff6b6b',
          margin: '0 2px',
          opacity: isRunning ? 1 : 0.5,
          transition: 'opacity 0.3s'
        }}>
          :
        </div>
        
        <RolodexDigit value={s1} />
        <RolodexDigit value={s2} />
      </div>
    </div>
  );
}