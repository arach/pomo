interface StatusDisplayProps {
  isRunning: boolean;
  isPaused: boolean;
  remaining: number;
  style?: React.CSSProperties;
  format?: string;
  position?: {
    x?: number | string;
    y?: number | string;
  };
}

export function StatusDisplay({ isRunning, isPaused, remaining, style, format, position }: StatusDisplayProps) {
  const getStatus = () => {
    if (remaining <= 0) return 'FINISHED';
    if (isPaused) return 'PAUSED';
    if (isRunning) return 'RUNNING';
    return 'READY';
  };

  const status = getStatus();
  const displayText = format ? format.replace('{status}', status) : status;
  
  const positionStyle: React.CSSProperties = {};
  
  if (position?.x === 'center' && typeof position?.y === 'number') {
    positionStyle.position = 'absolute';
    positionStyle.top = position.y;
    positionStyle.left = '50%';
    positionStyle.transform = 'translateX(-50%)';
  } else if (position?.x === 'center') {
    positionStyle.textAlign = 'center';
  } else if (position?.x === 'right' && position?.y === 'bottom') {
    positionStyle.position = 'absolute';
    positionStyle.bottom = '10px';
    positionStyle.right = '30px';
  }

  // Add success styling when finished
  const finishedStyle = remaining <= 0 ? {
    textShadow: '0 0 10px currentColor',
    animation: 'pulse 2s infinite'
  } : {};

  return (
    <div style={{ ...positionStyle, ...style, ...finishedStyle }}>
      <span>{displayText}</span>
    </div>
  );
}