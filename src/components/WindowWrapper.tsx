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
        overflow: 'hidden',
        boxShadow: '0 20px 25px -5px rgba(0, 0, 0, 0.3), 0 10px 10px -5px rgba(0, 0, 0, 0.04)'
      }}
    >
      {children}
    </div>
  );
}