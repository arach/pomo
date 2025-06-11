import { useEffect, useState } from 'react';

interface TerminalHeaderProps {
  text?: string;
  style?: React.CSSProperties;
}

export function TerminalHeader({ text = '$ pomo --duration=25m', style }: TerminalHeaderProps) {
  const [showCursor, setShowCursor] = useState(true);
  const [typedText, setTypedText] = useState('');
  const [isTyping, setIsTyping] = useState(true);

  useEffect(() => {
    if (isTyping && typedText.length < text.length) {
      const timeout = setTimeout(() => {
        setTypedText(text.slice(0, typedText.length + 1));
      }, 50 + Math.random() * 50);
      return () => clearTimeout(timeout);
    } else {
      setIsTyping(false);
    }
  }, [typedText, text, isTyping]);

  useEffect(() => {
    const interval = setInterval(() => {
      setShowCursor(prev => !prev);
    }, 530);
    return () => clearInterval(interval);
  }, []);

  const cursorStyle: React.CSSProperties = {
    display: 'inline-block',
    width: '0.6em',
    height: '1.2em',
    backgroundColor: 'currentColor',
    marginLeft: '2px',
    opacity: showCursor ? 1 : 0,
    transition: 'opacity 0.1s',
    verticalAlign: 'text-bottom'
  };

  return (
    <div style={{
      ...style,
      display: 'flex',
      alignItems: 'center',
      animation: 'textShadow 4s ease-in-out infinite'
    }} className="font-mono">
      <span style={{ color: '#00ff00', marginRight: '0.5em' }}>user@pomo:~$</span>
      <span>{typedText}</span>
      <span style={cursorStyle} />
    </div>
  );
}