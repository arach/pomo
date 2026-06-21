import { useEffect, useState, useRef } from 'react';

interface RolodexDisplayProps {
  remaining: number;
  isRunning: boolean;
}

interface DigitProps {
  value: string;
}

function RolodexDigit({ value }: DigitProps) {
  const [displayValue, setDisplayValue] = useState(value);
  const [nextValue, setNextValue] = useState(value);
  const [isFlipping, setIsFlipping] = useState(false);
  const animationTimeoutRef = useRef<NodeJS.Timeout>();

  useEffect(() => {
    // Skip if value hasn't changed
    if (value === displayValue && value === nextValue) return;

    // If we're already animating and get a new value, queue it
    if (isFlipping) {
      setNextValue(value);
      return;
    }

    // Start flip animation
    setNextValue(value);
    setIsFlipping(true);

    // Clear any existing timeout
    if (animationTimeoutRef.current) {
      clearTimeout(animationTimeoutRef.current);
    }

    // Update display value halfway through animation (when cards meet)
    const halfwayTimeout = setTimeout(() => {
      setDisplayValue(value);
    }, 300); // Half of the 600ms animation

    // End animation
    animationTimeoutRef.current = setTimeout(() => {
      setIsFlipping(false);
      // Check if we have a queued value
      if (nextValue !== value) {
        // Trigger next animation on next tick
        setTimeout(() => {
          setDisplayValue(nextValue);
        }, 0);
      }
    }, 600); // Total animation duration

    return () => {
      clearTimeout(halfwayTimeout);
      if (animationTimeoutRef.current) {
        clearTimeout(animationTimeoutRef.current);
      }
    };
  }, [value, displayValue, nextValue, isFlipping]);

  return (
    <div className="rolodex-digit">
      {/* Static halves - always show current display value */}
      <div className="digit-half digit-top">
        <span>{displayValue}</span>
      </div>
      <div className="digit-half digit-bottom">
        <span>{displayValue}</span>
      </div>

      {/* Animated halves - only show during flip */}
      {isFlipping && (
        <>
          {/* Top half flips away showing old value */}
          <div className="digit-half digit-top flip-top">
            <span>{displayValue}</span>
          </div>
          {/* Bottom half flips in showing new value */}
          <div className="digit-half digit-bottom flip-bottom">
            <span>{nextValue}</span>
          </div>
        </>
      )}

      <style>{`
        .rolodex-digit {
          position: relative;
          width: 60px;
          height: 90px;
          margin: 0 4px;
          perspective: 300px;
        }

        .digit-half {
          position: absolute;
          width: 100%;
          height: 50%;
          overflow: hidden;
          backface-visibility: hidden;
        }

        .digit-top {
          top: 0;
          background: #333;
          border-radius: 8px 8px 0 0;
          border-bottom: 1px solid #1a1a1a;
        }

        .digit-bottom {
          bottom: 0;
          background: #2a2a2a;
          border-radius: 0 0 8px 8px;
        }

        .digit-half span {
          position: absolute;
          width: 100%;
          font-size: 72px;
          font-family: 'Bebas Neue', sans-serif;
          color: #f0f0f0;
          text-align: center;
          line-height: 90px;
          text-shadow: 0 1px 2px rgba(0,0,0,0.5);
        }

        .digit-top span {
          top: 0;
        }

        .digit-bottom span {
          bottom: 0;
        }

        .flip-top {
          z-index: 2;
          transform-origin: bottom;
          animation: flipTop 0.3s ease-in forwards;
        }

        .flip-bottom {
          z-index: 1;
          transform-origin: top;
          animation: flipBottom 0.3s ease-out 0.3s forwards;
        }

        @keyframes flipTop {
          0% { transform: rotateX(0deg); }
          100% { transform: rotateX(-90deg); }
        }

        @keyframes flipBottom {
          0% { transform: rotateX(90deg); }
          100% { transform: rotateX(0deg); }
        }

        /* Box shadow for depth */
        .rolodex-digit::before {
          content: '';
          position: absolute;
          width: 100%;
          height: 100%;
          background: transparent;
          border-radius: 8px;
          box-shadow: inset 0 2px 4px rgba(0,0,0,0.3), 0 4px 8px rgba(0,0,0,0.5);
          pointer-events: none;
          z-index: 3;
        }
      `}</style>
    </div>
  );
}

export function RolodexDisplay({ remaining, isRunning }: RolodexDisplayProps) {
  const mins = Math.floor(remaining / 60).toString().padStart(2, '0');
  const secs = (remaining % 60).toString().padStart(2, '0');

  return (
    <div style={{
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      gap: '8px'
    }}>
      {/* Minutes */}
      <div style={{ display: 'flex' }}>
        <RolodexDigit value={mins[0]} />
        <RolodexDigit value={mins[1]} />
      </div>

      {/* Separator */}
      <div style={{
        fontSize: '48px',
        fontFamily: "'Bebas Neue', sans-serif",
        color: '#ff6b6b',
        margin: '0 8px',
        opacity: isRunning ? 1 : 0.5,
        transition: 'opacity 0.3s',
        textShadow: '0 0 10px rgba(255, 107, 107, 0.5)'
      }}>
        :
      </div>

      {/* Seconds */}
      <div style={{ display: 'flex' }}>
        <RolodexDigit value={secs[0]} />
        <RolodexDigit value={secs[1]} />
      </div>
    </div>
  );
}