interface MinimalProgressDotProps {
  progress: number;
  style?: React.CSSProperties;
  isRunning?: boolean;
  isPaused?: boolean;
}

export function MinimalProgressDot({ progress, style, isRunning, isPaused }: MinimalProgressDotProps) {
  const dotStyle: React.CSSProperties = {
    width: '6px',
    height: '6px',
    borderRadius: '50%',
    backgroundColor: 'currentColor',
    opacity: isRunning && !isPaused ? 0.4 + (progress * 0.6) : 0.2,
    transition: 'opacity 0.3s ease',
    ...style
  };

  return <div style={dotStyle} />;
}