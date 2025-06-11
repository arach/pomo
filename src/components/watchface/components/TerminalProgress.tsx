interface TerminalProgressProps {
  progress: number;
  width?: number;
  fillChar?: string;
  emptyChar?: string;
  style?: React.CSSProperties;
}

export function TerminalProgress({
  progress,
  width = 30,
  fillChar = '█',
  emptyChar = '░',
  style
}: TerminalProgressProps) {
  const filled = Math.round((progress / 100) * width);
  const empty = width - filled;
  
  const progressBar = fillChar.repeat(Math.max(0, filled)) + emptyChar.repeat(Math.max(0, empty));
  const percentage = `${Math.round(progress)}%`.padStart(3, ' ');
  
  return (
    <div style={style} className="text-center">
      <div className="font-mono text-xs">
        [{progressBar}]
      </div>
      <div className="font-mono text-xs mt-1">
        {percentage}
      </div>
    </div>
  );
}