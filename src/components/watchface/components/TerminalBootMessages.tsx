import { useEffect, useState } from 'react';

interface TerminalBootMessagesProps {
  isRunning: boolean;
  style?: React.CSSProperties;
  position?: {
    x?: number | string;
    y?: number | string;
  };
}

export function TerminalBootMessages({ isRunning, style, position }: TerminalBootMessagesProps) {
  const [messages, setMessages] = useState<string[]>([]);
  const [currentMessage, setCurrentMessage] = useState(0);

  const bootMessages = [
    'Initializing focus protocol...',
    'Loading cognitive enhancement modules...',
    'Establishing deep work connection...',
    'Productivity systems online.',
    'Ready to focus. Timer armed.'
  ];

  useEffect(() => {
    if (isRunning && messages.length === 0) {
      // Start boot sequence when timer starts
      let messageIndex = 0;
      const interval = setInterval(() => {
        if (messageIndex < bootMessages.length) {
          setMessages(prev => [...prev, bootMessages[messageIndex]]);
          setCurrentMessage(messageIndex);
          messageIndex++;
        } else {
          clearInterval(interval);
          // Clear messages after showing them all
          setTimeout(() => {
            setMessages([]);
            setCurrentMessage(0);
          }, 2000);
        }
      }, 400);

      return () => clearInterval(interval);
    } else if (!isRunning) {
      // Reset when timer stops
      setMessages([]);
      setCurrentMessage(0);
    }
  }, [isRunning]);

  const positionStyle: React.CSSProperties = {};
  
  if (position?.x !== undefined && position?.y !== undefined) {
    positionStyle.position = 'absolute';
    positionStyle.left = position.x;
    positionStyle.top = position.y;
  }

  if (messages.length === 0) return null;

  return (
    <div 
      style={{
        ...positionStyle,
        ...style,
        fontFamily: "'SF Mono', monospace",
        fontSize: '9px',
        color: '#00ff00',
        opacity: 0.8
      }}
    >
      {messages.map((message, index) => (
        <div key={index} style={{ marginBottom: '2px' }}>
          <span style={{ opacity: 0.6 }}>{'>'}</span> {message}
        </div>
      ))}
    </div>
  );
}