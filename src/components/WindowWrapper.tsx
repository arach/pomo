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
        background: 'rgb(18, 19, 23)',
        borderRadius: '10px',
        overflow: 'hidden',
        border: 'none',
        outline: 'none'
      }}
    >
      {children}
    </div>
  );
}