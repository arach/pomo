interface TimeDisplayProps {
  remaining: number;
  style?: React.CSSProperties;
  position?: {
    x?: number | string;
    y?: number | string;
  };
}

export function TimeDisplay({ remaining, style, position }: TimeDisplayProps) {
  const formatTime = (seconds: number) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  };

  const positionStyle: React.CSSProperties = {};
  
  if (position?.x === 'center' && position?.y === 'center') {
    positionStyle.position = 'absolute';
    positionStyle.top = '50%';
    positionStyle.left = '50%';
    positionStyle.transform = 'translate(-50%, -50%)';
  } else if (position?.x === 'center' && typeof position?.y === 'number') {
    positionStyle.position = 'absolute';
    positionStyle.top = position.y;
    positionStyle.left = '50%';
    positionStyle.transform = 'translateX(-50%)';
  } else if (position?.x === 'center') {
    positionStyle.textAlign = 'center';
  }

  return (
    <div style={{ ...positionStyle, ...style }}>
      <span className="tabular-nums tracking-tight">
        {formatTime(remaining)}
      </span>
    </div>
  );
}