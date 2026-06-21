import React from 'react';

interface ClickableTimeWrapperProps {
  children: React.ReactNode;
  onClick?: () => void;
  isRunning?: boolean;
  style?: React.CSSProperties;
}

export function ClickableTimeWrapper({ 
  children, 
  onClick, 
  isRunning = false,
  style 
}: ClickableTimeWrapperProps) {
  if (!onClick || isRunning) {
    return <>{children}</>;
  }

  return (
    <div 
      onClick={onClick}
      style={{
        ...style,
        cursor: 'pointer',
        userSelect: 'none',
        transition: 'opacity 0.2s',
      }}
      className="hover:opacity-80"
      title="Click to set timer"
    >
      {children}
    </div>
  );
}