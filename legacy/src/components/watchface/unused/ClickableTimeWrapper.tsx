import { ReactNode } from 'react';

interface ClickableTimeWrapperProps {
  children: ReactNode;
  onClick: () => void;
  isRunning: boolean;
}

export function ClickableTimeWrapper({ children, onClick, isRunning }: ClickableTimeWrapperProps) {
  if (isRunning) {
    return <>{children}</>;
  }

  return (
    <div 
      onClick={onClick}
      className="cursor-pointer hover:opacity-80 transition-opacity"
      title="Click to set duration"
    >
      {children}
    </div>
  );
}