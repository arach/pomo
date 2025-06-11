import React from 'react';

interface ChronographFaceProps {
  style?: React.CSSProperties;
}

export function ChronographFace({ style }: ChronographFaceProps) {
  return (
    <div style={style} className="chronograph-face" />
  );
}