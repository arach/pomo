import { ReactNode } from 'react';

interface WindowWrapperProps {
  children: ReactNode;
  className?: string;
}

export function WindowWrapper({ children, className = '' }: WindowWrapperProps) {
  return (
    <div 
      className={`w-full h-full text-foreground flex flex-col ${className}`}
      style={{ 
        background: 'rgba(18, 19, 23, 0.95)',
        borderRadius: '10px',
        overflow: 'hidden'
      }}
    >
      {children}
    </div>
  );
}