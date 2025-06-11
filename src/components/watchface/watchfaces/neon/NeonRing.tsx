import React from 'react';

interface NeonRingProps {
  radius: number;
  style?: React.CSSProperties;
}

export function NeonRing({ radius, style }: NeonRingProps) {
  return (
    <svg
      width={radius * 2}
      height={radius * 2}
      style={{
        position: 'absolute',
        left: '50%',
        top: '50%',
        transform: 'translate(-50%, -50%)',
        ...style
      }}
    >
      <style>
        {`
          @keyframes pulse {
            0%, 100% { opacity: 0.6; }
            50% { opacity: 1; }
          }
        `}
      </style>
      <circle
        cx={radius}
        cy={radius}
        r={radius - 1}
        style={{
          ...style,
          animation: style?.animation || 'pulse 2s ease-in-out infinite'
        }}
      />
    </svg>
  );
}