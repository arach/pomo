import { useEffect, useState, useRef } from 'react';

interface TerminalProgressV2Props {
  progress: number;
  width?: number;
  fillChar?: string;
  emptyChar?: string;
  style?: React.CSSProperties;
}

export function TerminalProgressV2({
  progress,
  width = 42,
  fillChar = '█',
  emptyChar = '░',
  style
}: TerminalProgressV2Props) {
  const [animFrame, setAnimFrame] = useState(0);
  const [glitchFrame, setGlitchFrame] = useState(0);
  const [matrixDrops, setMatrixDrops] = useState<number[]>([]);
  const containerRef = useRef<HTMLDivElement>(null);
  const spinners = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];
  const matrixChars = '01ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
  
  useEffect(() => {
    const interval = setInterval(() => {
      setAnimFrame(prev => (prev + 1) % spinners.length);
    }, 100);
    return () => clearInterval(interval);
  }, [spinners.length]);
  
  // CRT glitch effect
  useEffect(() => {
    const glitchInterval = setInterval(() => {
      setGlitchFrame(Math.random());
    }, 3000 + Math.random() * 5000);
    return () => clearInterval(glitchInterval);
  }, []);
  
  // Matrix rain effect
  useEffect(() => {
    const columns = 20;
    const drops = Array(columns).fill(0).map(() => Math.random() * -100);
    setMatrixDrops(drops);
    
    const matrixInterval = setInterval(() => {
      setMatrixDrops(prev => prev.map(drop => {
        if (drop > 100) return Math.random() * -100;
        return drop + 2;
      }));
    }, 50);
    
    return () => clearInterval(matrixInterval);
  }, []);

  const filled = Math.round((progress / 100) * width);
  const empty = width - filled;
  
  const progressBar = fillChar.repeat(Math.max(0, filled)) + emptyChar.repeat(Math.max(0, empty));
  const percentage = `${Math.round(progress)}%`.padStart(4, ' ');
  
  const progressColor = progress < 33 ? '#00ff00' : progress < 66 ? '#ffd93d' : '#00ff00';
  
  // Simulate scanlines
  const scanlineOpacity = 0.03 + Math.sin(Date.now() / 1000) * 0.01;
  
  return (
    <div style={{
      ...style,
      fontFamily: 'monospace',
      lineHeight: 1.4,
      position: 'relative',
      filter: glitchFrame > 0.95 ? 'blur(0.5px)' : 'none',
      transform: glitchFrame > 0.98 ? 'translateX(1px)' : 'none'
    }} ref={containerRef}>
      {/* Matrix rain background */}
      <div style={{
        position: 'absolute',
        inset: '-20px',
        overflow: 'hidden',
        opacity: 0.15,
        pointerEvents: 'none',
        zIndex: 0
      }}>
        {matrixDrops.map((drop, i) => (
          <div key={i} style={{
            position: 'absolute',
            left: `${(i / matrixDrops.length) * 100}%`,
            top: `${drop}%`,
            color: '#00ff00',
            fontSize: '10px',
            fontFamily: 'monospace',
            textShadow: '0 0 5px #00ff00',
            opacity: Math.max(0, 1 - (drop / 100))
          }}>
            {matrixChars[Math.floor(Math.random() * matrixChars.length)]}
          </div>
        ))}
      </div>
      
      {/* V2 indicator with animation */}
      <div style={{
        position: 'absolute',
        top: -25,
        right: 0,
        background: '#00ff00',
        color: '#000',
        padding: '1px 4px',
        fontSize: '8px',
        fontWeight: 'bold',
        border: '1px solid #00ff00',
        boxShadow: '0 0 5px #00ff00',
        animation: 'v2pulse 2s ease-in-out infinite'
      }}>
        V2.0
      </div>
      
      {/* CRT scanlines overlay */}
      <div style={{
        position: 'absolute',
        inset: 0,
        background: `repeating-linear-gradient(
          0deg,
          rgba(0, 255, 0, ${scanlineOpacity}),
          rgba(0, 255, 0, ${scanlineOpacity}) 1px,
          transparent 1px,
          transparent 2px
        )`,
        pointerEvents: 'none',
        zIndex: 10
      }} />
      
      <div style={{ marginBottom: '8px', opacity: 0.7, fontSize: '9px' }}>
        ┌─ Progress ───────────────────────────────────────┐
      </div>
      <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
        <span style={{ opacity: 0.5 }}>│</span>
        <span style={{ 
          color: progressColor,
          textShadow: `0 0 5px ${progressColor}, 0 0 10px ${progressColor}`,
          letterSpacing: '-1px',
          filter: 'brightness(1.2)'
        }}>
          {progressBar}
        </span>
        <span style={{ 
          color: progressColor,
          textShadow: `0 0 3px ${progressColor}`,
          animation: 'terminalBlink 1s infinite'
        }}>
          {spinners[animFrame]}
        </span>
        <span style={{ 
          color: progressColor,
          fontWeight: 'bold',
          minWidth: '5px',
          textAlign: 'right',
          textShadow: `0 0 3px ${progressColor}`
        }}>
          {percentage}
        </span>
        <span style={{ opacity: 0.5, paddingLeft: percentage.length === 4 ? '3px' : '8px' }}>│</span>
      </div>
      <div style={{ marginTop: '8px', opacity: 0.7, fontSize: '9px' }}>
        └──────────────────────────────────────────────────┘
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
      
      {/* Additional status info for V2 */}
      <div style={{
        marginTop: '12px',
        fontSize: '8px',
        opacity: 0.4,
        textAlign: 'center',
        fontFamily: 'monospace',
        letterSpacing: '1px'
      }}>
        <span style={{ color: '#00ff00' }}>SYS:</span> OK | 
        <span style={{ color: '#00ff00' }}> CPU:</span> {Math.round(progress * 0.8 + 20)}% | 
        <span style={{ color: '#00ff00' }}> MEM:</span> {Math.round(progress * 0.5 + 40)}%
      </div>
      
      <style>{`
        @keyframes terminalBlink {
          0%, 100% { opacity: 1; }
          50% { opacity: 0.6; }
        }
        @keyframes v2pulse {
          0%, 100% { transform: scale(1); opacity: 1; }
          50% { transform: scale(1.05); opacity: 0.9; }
        }
      `}</style>
    </div>
  );
}