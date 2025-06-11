import { useEffect, useState, useRef } from 'react';

interface RolodexDisplayProps {
  remaining: number;
  isRunning: boolean;
}

interface DigitProps {
  value: string;
}

// Simple state machine for flip animation
type FlipState = 'idle' | 'flipping';

function RolodexDigit({ value }: DigitProps) {
  const [state, setState] = useState<FlipState>('idle');
  const [currentValue, setCurrentValue] = useState(value);
  const [targetValue, setTargetValue] = useState(value);
  const lastValue = useRef(value);

  useEffect(() => {
    if (value !== lastValue.current) {
      lastValue.current = value;
      setTargetValue(value);
      setState('flipping');
    }
  }, [value]);

  const handleAnimationEnd = () => {
    setCurrentValue(targetValue);
    setState('idle');
  };

  // Determine what to show based on state
  const topValue = state === 'idle' ? currentValue : currentValue;
  const bottomValue = state === 'idle' ? currentValue : currentValue;
  const flipTopValue = currentValue;
  const flipBottomValue = targetValue;

  return (
    <div className="relative w-[60px] h-[90px] mx-1" style={{ perspective: '300px' }}>
      {/* Background card with shadow */}
      <div className="absolute inset-0 bg-[#2a2a2a] rounded-lg shadow-[inset_0_2px_4px_rgba(0,0,0,0.3),0_4px_8px_rgba(0,0,0,0.5)]" />
      
      {/* Static display - always visible */}
      <div className="absolute inset-0 overflow-hidden rounded-lg">
        {/* Top half */}
        <div className="absolute w-full h-1/2 bg-[#333] border-b border-[#1a1a1a] overflow-hidden">
          <div className="absolute w-full text-[72px] text-[#f0f0f0] text-center leading-[90px] font-['Bebas_Neue'] drop-shadow-[0_1px_2px_rgba(0,0,0,0.5)]">
            {topValue}
          </div>
        </div>
        
        {/* Bottom half */}
        <div className="absolute w-full h-1/2 bottom-0 bg-[#2a2a2a] overflow-hidden">
          <div className="absolute w-full bottom-0 text-[72px] text-[#f0f0f0] text-center leading-[90px] font-['Bebas_Neue'] drop-shadow-[0_1px_2px_rgba(0,0,0,0.5)]">
            {bottomValue}
          </div>
        </div>
      </div>

      {/* Flip animation overlays */}
      {state === 'flipping' && (
        <>
          {/* Top half flipping away */}
          <div 
            className="absolute w-full h-1/2 bg-[#333] border-b border-[#1a1a1a] overflow-hidden z-20"
            style={{
              transformOrigin: 'bottom',
              animation: 'flipTop 0.3s ease-in forwards'
            }}
          >
            <div className="absolute w-full text-[72px] text-[#f0f0f0] text-center leading-[90px] font-['Bebas_Neue'] drop-shadow-[0_1px_2px_rgba(0,0,0,0.5)]">
              {flipTopValue}
            </div>
          </div>

          {/* Bottom half flipping in */}
          <div 
            className="absolute w-full h-1/2 bottom-0 bg-[#2a2a2a] overflow-hidden z-10"
            style={{
              transformOrigin: 'top',
              animation: 'flipBottom 0.3s ease-out 0.3s forwards'
            }}
            onAnimationEnd={handleAnimationEnd}
          >
            <div className="absolute w-full bottom-0 text-[72px] text-[#f0f0f0] text-center leading-[90px] font-['Bebas_Neue'] drop-shadow-[0_1px_2px_rgba(0,0,0,0.5)]">
              {flipBottomValue}
            </div>
          </div>
        </>
      )}

      <style jsx>{`
        @keyframes flipTop {
          from { transform: rotateX(0deg); }
          to { transform: rotateX(-90deg); }
        }
        
        @keyframes flipBottom {
          from { transform: rotateX(90deg); }
          to { transform: rotateX(0deg); }
        }
      `}</style>
    </div>
  );
}

export function RolodexDisplay({ remaining, isRunning }: RolodexDisplayProps) {
  const mins = Math.floor(remaining / 60).toString().padStart(2, '0');
  const secs = (remaining % 60).toString().padStart(2, '0');

  return (
    <div className="flex items-center justify-center gap-2">
      {/* Minutes */}
      <div className="flex">
        <RolodexDigit value={mins[0]} />
        <RolodexDigit value={mins[1]} />
      </div>

      {/* Separator */}
      <div 
        className="text-5xl text-[#ff6b6b] mx-2 font-['Bebas_Neue'] transition-opacity duration-300"
        style={{
          opacity: isRunning ? 1 : 0.5,
          textShadow: '0 0 10px rgba(255, 107, 107, 0.5)'
        }}
      >
        :
      </div>

      {/* Seconds */}
      <div className="flex">
        <RolodexDigit value={secs[0]} />
        <RolodexDigit value={secs[1]} />
      </div>
    </div>
  );
}