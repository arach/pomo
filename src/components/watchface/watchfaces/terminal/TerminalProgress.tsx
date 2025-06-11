import { useEffect, useState } from 'react';

interface TerminalProgressProps {
  progress: number;
  width?: number;
  fillChar?: string;
  emptyChar?: string;
  style?: React.CSSProperties;
}

export function TerminalProgress({
  progress,
  width = 40,
  fillChar = '█',
  emptyChar = '░',
  style
}: TerminalProgressProps) {
  const [animFrame, setAnimFrame] = useState(0);
  const spinners = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];
  
  useEffect(() => {
    const interval = setInterval(() => {
      setAnimFrame(prev => (prev + 1) % spinners.length);
    }, 100);
    return () => clearInterval(interval);
  }, [spinners.length]);

  const filled = Math.round((progress / 100) * width);
  const empty = width - filled;
  
  const progressBar = fillChar.repeat(Math.max(0, filled)) + emptyChar.repeat(Math.max(0, empty));
  const percentage = `${Math.round(progress)}%`.padStart(4, ' ');
  
  const progressColor = progress < 33 ? '#ff6b6b' : progress < 66 ? '#ffd93d' : '#00ff00';
  
  return (
    <div style={{
      ...style,
      fontFamily: 'monospace',
      lineHeight: 1.4
    }}>
      <div style={{ marginBottom: '12px', opacity: 0.7, fontSize: '10px' }}>
        ┌─ Progress ───────────────────────────────┐
      </div>
      <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
        <span style={{ opacity: 0.5 }}>│</span>
        <span style={{ color: progressColor }}>
          {spinners[animFrame]}
        </span>
        <span style={{ 
          color: progressColor,
          textShadow: `0 0 5px ${progressColor}`,
          letterSpacing: '-1px'
        }}>
          [{progressBar}]
        </span>
        <span style={{ 
          color: progressColor,
          fontWeight: 'bold',
          minWidth: '45px',
          textAlign: 'right'
        }}>
          {percentage}
        </span>
        <span style={{ opacity: 0.5 }}>│</span>
      </div>
      <div style={{ marginTop: '12px', opacity: 0.7, fontSize: '10px' }}>
        └──────────────────────────────────────────┘
      </div>
      <div style={{ 
        marginTop: '8px', 
        fontSize: '9px', 
        opacity: 0.5,
        display: 'flex',
        justifyContent: 'space-between',
        paddingLeft: '20px',
        paddingRight: '20px'
      }}>
        <span>0%</span>
        <span>25%</span>
        <span>50%</span>
        <span>75%</span>
        <span>100%</span>
      </div>
    </div>
  );
}