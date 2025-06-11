import React, { useState } from 'react';

interface TerminalControlsProps {
  isRunning: boolean;
  isPaused: boolean;
  onStart: () => void;
  onPause: () => void;
  onStop: () => void;
  style?: React.CSSProperties;
}

export function TerminalControls({
  isRunning,
  isPaused,
  onStart,
  onPause,
  onStop,
  style
}: TerminalControlsProps) {
  const [hoveredCommand, setHoveredCommand] = useState<string | null>(null);

  const handleCommand = (action: string) => {
    switch (action) {
      case 'start':
        onStart();
        break;
      case 'pause':
        onPause();
        break;
      case 'stop':
        onStop();
        break;
    }
  };

  const commandStyle = (command: string): React.CSSProperties => ({
    cursor: 'pointer',
    padding: '2px 4px',
    backgroundColor: hoveredCommand === command ? 'rgba(0, 255, 0, 0.2)' : 'transparent',
    color: hoveredCommand === command ? '#00ff00' : 'inherit',
    transition: 'all 0.1s',
    textShadow: hoveredCommand === command ? '0 0 5px currentColor' : 'none',
    animation: hoveredCommand === command ? 'textShadow 1s ease-in-out infinite' : 'none'
  });

  const renderPrompt = () => {
    if (!isRunning || isPaused) {
      return (
        <>
          <div style={{ marginBottom: '8px', opacity: 0.7, fontSize: '10px' }}>
            ┌─ Available Commands ─────────────┐
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <span style={{ opacity: 0.5 }}>│</span>
            <span 
              onClick={() => handleCommand('start')}
              onMouseEnter={() => setHoveredCommand('start')}
              onMouseLeave={() => setHoveredCommand(null)}
              style={commandStyle('start')}
            >
              [S] START
            </span>
            <span style={{ opacity: 0.3 }}>│</span>
            <span 
              onClick={() => handleCommand('stop')}
              onMouseEnter={() => setHoveredCommand('stop')}
              onMouseLeave={() => setHoveredCommand(null)}
              style={commandStyle('stop')}
            >
              [R] RESET
            </span>
            <span style={{ opacity: 0.5 }}>│</span>
          </div>
          <div style={{ marginTop: '8px', opacity: 0.7, fontSize: '10px' }}>
            └──────────────────────────────────┘
          </div>
        </>
      );
    }

    return (
      <>
        <div style={{ marginBottom: '8px', opacity: 0.7, fontSize: '10px' }}>
          ┌─ Running ────────────────────────┐
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          <span style={{ opacity: 0.5 }}>│</span>
          <span 
            onClick={() => handleCommand('pause')}
            onMouseEnter={() => setHoveredCommand('pause')}
            onMouseLeave={() => setHoveredCommand(null)}
            style={commandStyle('pause')}
          >
            [P] PAUSE
          </span>
          <span style={{ opacity: 0.3 }}>│</span>
          <span 
            onClick={() => handleCommand('stop')}
            onMouseEnter={() => setHoveredCommand('stop')}
            onMouseLeave={() => setHoveredCommand(null)}
            style={commandStyle('stop')}
          >
            [X] STOP
          </span>
          <span style={{ opacity: 0.5 }}>│</span>
        </div>
        <div style={{ marginTop: '8px', opacity: 0.7, fontSize: '10px' }}>
          └──────────────────────────────────┘
        </div>
      </>
    );
  };

  return (
    <div style={{
      ...style,
      fontFamily: 'monospace',
      lineHeight: 1.2
    }}>
      {renderPrompt()}
    </div>
  );
}