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
        background: 'rgb(26, 26, 26)',
        borderRadius: '10px',
        overflow: 'hidden',
        border: 'none',
        outline: 'none',
        boxShadow: '0 8px 32px rgba(0, 0, 0, 0.4)'
      }}
    >
      {children}
    </div>
  );
}