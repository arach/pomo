import { useEffect, useState } from 'react';

interface TerminalCursorProps {
  style?: React.CSSProperties;
  position?: {
    x?: number | string;
    y?: number | string;
  };
}

export function TerminalCursor({ style, position }: TerminalCursorProps) {
  const [visible, setVisible] = useState(true);

  useEffect(() => {
    const interval = setInterval(() => {
      setVisible(prev => !prev);
    }, 530); // Classic terminal cursor blink rate

    return () => clearInterval(interval);
  }, []);

  const positionStyle: React.CSSProperties = {};
  
  if (position?.x !== undefined && position?.y !== undefined) {
    positionStyle.position = 'absolute';
    positionStyle.left = position.x;
    positionStyle.top = position.y;
  }

  return (
    <div 
      style={{
        ...positionStyle,
        ...style,
        opacity: visible ? 1 : 0,
        transition: 'none'
      }}
    >
      █
    </div>
  );
}