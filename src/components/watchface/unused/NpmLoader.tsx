import React, { useEffect, useState } from 'react';

interface NpmLoaderProps {
  progress: number; // 0-100
  isRunning?: boolean;
  style?: React.CSSProperties;
  reverse?: boolean;
}

export function NpmLoader({ progress, isRunning = false, style, reverse = true }: NpmLoaderProps) {
  // NPM-style braille spinner characters
  const spinnerChars = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];
  const [currentChar, setCurrentChar] = useState(0);
  
  useEffect(() => {
    if (!isRunning) {
      // Stop animation when timer is not running
      setCurrentChar(0);
      return;
    }

    const interval = setInterval(() => {
      setCurrentChar((prev) => {
        if (reverse) {
          // Reverse animation - go backwards through the spinner
          return prev === 0 ? spinnerChars.length - 1 : prev - 1;
        } else {
          // Normal animation
          return (prev + 1) % spinnerChars.length;
        }
      });
    }, 100); // 100ms interval for smooth animation
    
    return () => clearInterval(interval);
  }, [reverse, isRunning, spinnerChars.length]);
  
  // Generate progress bar with filled and empty sections
  const totalChars = 25;
  const filledChars = Math.floor((progress / 100) * totalChars);
  const emptyChars = totalChars - filledChars;
  
  const progressBar = '▓'.repeat(filledChars) + '░'.repeat(emptyChars);
  const spinner = spinnerChars[currentChar];
  
  return (
    <div style={{
      fontFamily: "'SF Mono', monospace",
      fontSize: '12px',
      color: '#00ff00',
      ...style
    }}>
      {spinner} [{progressBar}] {Math.round(progress)}%
    </div>
  );
}