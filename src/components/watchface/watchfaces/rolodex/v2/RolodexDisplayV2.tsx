import { useState, useEffect } from 'react';

interface RolodexDisplayV2Props {
  remaining: number;
  isRunning: boolean;
  onTimeClick?: () => void;
}

export function RolodexDisplayV2({ remaining, isRunning, onTimeClick }: RolodexDisplayV2Props) {
  const formatTime = (seconds: number) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return {
      minutes: mins.toString().padStart(2, '0'),
      seconds: secs.toString().padStart(2, '0')
    };
  };

  const time = formatTime(remaining);
  const [prevTime, setPrevTime] = useState(time);
  const [isFlipping, setIsFlipping] = useState({ m1: false, m2: false, s1: false, s2: false });

  useEffect(() => {
    const newTime = formatTime(remaining);
    const flips = {
      m1: prevTime.minutes[0] !== newTime.minutes[0],
      m2: prevTime.minutes[1] !== newTime.minutes[1],
      s1: prevTime.seconds[0] !== newTime.seconds[0],
      s2: prevTime.seconds[1] !== newTime.seconds[1]
    };
    
    setIsFlipping(flips);
    
    const timeout = setTimeout(() => {
      setPrevTime(newTime);
      setIsFlipping({ m1: false, m2: false, s1: false, s2: false });
    }, 300);
    
    return () => clearTimeout(timeout);
  }, [remaining]);

  const RolodexDigit = ({ value, prevValue, isFlipping, position }: any) => (
    <div style={{
      position: 'relative',
      width: '45px',
      height: '60px',
      margin: '0 2px',
      perspective: '200px',
      transformStyle: 'preserve-3d'
    }}>
      {/* V2 indicator for first digit only */}
      {position === 0 && (
        <div style={{
          position: 'absolute',
          top: -15,
          right: -10,
          background: 'linear-gradient(45deg, #FFD700, #FFA500)',
          color: '#000',
          padding: '2px 6px',
          borderRadius: '8px',
          fontSize: '8px',
          fontWeight: 'bold',
          zIndex: 100,
          boxShadow: '0 2px 8px rgba(255, 215, 0, 0.5)'
        }}>
          V2
        </div>
      )}
      
      {/* Background card with depth */}
      <div style={{
        position: 'absolute',
        width: '100%',
        height: '100%',
        background: 'linear-gradient(145deg, #1a1a1a, #0a0a0a)',
        borderRadius: '8px',
        boxShadow: 'inset 0 2px 5px rgba(0,0,0,0.5), 0 5px 15px rgba(0,0,0,0.8)',
        overflow: 'hidden',
        border: '1px solid #333'
      }}>
        {/* Metal frame effect */}
        <div style={{
          position: 'absolute',
          inset: '2px',
          borderRadius: '6px',
          background: 'linear-gradient(145deg, #2a2a2a, #111)',
          boxShadow: 'inset 0 1px 2px rgba(255,255,255,0.1)'
        }} />
        
        {/* Split line */}
        <div style={{
          position: 'absolute',
          left: 0,
          right: 0,
          height: '1px',
          top: '50%',
          background: 'linear-gradient(90deg, transparent, #444, transparent)',
          zIndex: 10
        }} />
      </div>

      {/* Current value (static) */}
      <div style={{
        position: 'absolute',
        width: '100%',
        height: '100%',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        fontSize: '36px',
        fontWeight: '700',
        fontFamily: "'Bebas Neue', sans-serif",
        color: '#FFD700',
        textShadow: '0 0 10px rgba(255, 215, 0, 0.5), 0 2px 4px rgba(0,0,0,0.8)',
        zIndex: 5,
        letterSpacing: '2px'
      }}>
        {value}
      </div>

      {/* Flipping animation */}
      {isFlipping && (
        <>
          {/* Top half (flipping away) */}
          <div style={{
            position: 'absolute',
            width: '100%',
            height: '50%',
            top: 0,
            overflow: 'hidden',
            transformOrigin: 'bottom',
            transform: `rotateX(${isFlipping ? '-90deg' : '0deg'})`,
            transition: 'transform 0.3s ease-in',
            zIndex: 20,
            backfaceVisibility: 'hidden'
          }}>
            <div style={{
              position: 'absolute',
              width: '100%',
              height: '200%',
              background: 'linear-gradient(145deg, #1a1a1a, #0a0a0a)',
              borderRadius: '8px 8px 0 0',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              fontSize: '36px',
              fontWeight: '700',
              fontFamily: "'Bebas Neue', sans-serif",
              color: '#FFD700',
              textShadow: '0 0 10px rgba(255, 215, 0, 0.5)',
              letterSpacing: '2px'
            }}>
              {prevValue}
            </div>
          </div>

          {/* Bottom half (flipping in) */}
          <div style={{
            position: 'absolute',
            width: '100%',
            height: '50%',
            bottom: 0,
            overflow: 'hidden',
            transformOrigin: 'top',
            transform: `rotateX(${isFlipping ? '0deg' : '90deg'})`,
            transition: 'transform 0.3s ease-out 0.15s',
            zIndex: 15
          }}>
            <div style={{
              position: 'absolute',
              width: '100%',
              height: '200%',
              top: '-100%',
              background: 'linear-gradient(145deg, #0a0a0a, #1a1a1a)',
              borderRadius: '0 0 8px 8px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              fontSize: '36px',
              fontWeight: '700',
              fontFamily: "'Bebas Neue', sans-serif",
              color: '#FFD700',
              textShadow: '0 0 10px rgba(255, 215, 0, 0.5)',
              letterSpacing: '2px'
            }}>
              {value}
            </div>
          </div>
        </>
      )}
    </div>
  );

  return (
    <div 
      onClick={onTimeClick}
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: '10px',
        cursor: !isRunning ? 'pointer' : 'default',
        userSelect: 'none',
        padding: '20px',
        position: 'relative'
      }}
    >
      {/* Ambient lighting effect */}
      <div style={{
        position: 'absolute',
        inset: '-20px',
        background: 'radial-gradient(ellipse at center, rgba(255, 215, 0, 0.1), transparent 70%)',
        filter: 'blur(20px)',
        pointerEvents: 'none'
      }} />
      
      {/* Minutes */}
      <div style={{ display: 'flex', position: 'relative', zIndex: 1 }}>
        <RolodexDigit 
          value={time.minutes[0]} 
          prevValue={prevTime.minutes[0]} 
          isFlipping={isFlipping.m1}
          position={0}
        />
        <RolodexDigit 
          value={time.minutes[1]} 
          prevValue={prevTime.minutes[1]} 
          isFlipping={isFlipping.m2}
          position={1}
        />
      </div>

      {/* Colon separator with pulsing effect */}
      <div style={{
        fontSize: '32px',
        fontWeight: '700',
        color: '#FFD700',
        textShadow: '0 0 10px rgba(255, 215, 0, 0.5)',
        animation: 'colonPulse 2s ease-in-out infinite',
        zIndex: 1
      }}>
        :
      </div>

      {/* Seconds */}
      <div style={{ display: 'flex', position: 'relative', zIndex: 1 }}>
        <RolodexDigit 
          value={time.seconds[0]} 
          prevValue={prevTime.seconds[0]} 
          isFlipping={isFlipping.s1}
          position={2}
        />
        <RolodexDigit 
          value={time.seconds[1]} 
          prevValue={prevTime.seconds[1]} 
          isFlipping={isFlipping.s2}
          position={3}
        />
      </div>

      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=Bebas+Neue&display=swap');
        
        @keyframes colonPulse {
          0%, 100% { opacity: 1; transform: scale(1); }
          50% { opacity: 0.7; transform: scale(0.9); }
        }
      `}</style>
    </div>
  );
}