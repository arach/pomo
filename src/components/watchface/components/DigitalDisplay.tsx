import React from 'react';

interface DigitalDisplayProps {
  style?: React.CSSProperties;
  children?: React.ReactNode;
}

export function DigitalDisplay({ style, children }: DigitalDisplayProps) {
  return (
    <div style={style} className="digital-display">
      {children}
    </div>
  );
}