import React, { useState, ReactNode } from 'react';
import { Bug, X, LucideIcon } from 'lucide-react';

export interface DevToolbarTab {
  id: string;
  label: string;
  icon: LucideIcon;
  content: ReactNode | (() => ReactNode);
}

export interface DevToolbarProps {
  tabs: DevToolbarTab[];
  position?: 'bottom-right' | 'bottom-left' | 'top-right' | 'top-left';
  defaultTab?: string;
  className?: string;
  theme?: 'dark' | 'light' | 'auto';
  hideInProduction?: boolean;
  customIcon?: ReactNode;
  title?: string;
  width?: string;
  maxHeight?: string;
}

export const DevToolbar: React.FC<DevToolbarProps> = ({
  tabs,
  position = 'bottom-right',
  defaultTab,
  className = '',
  theme = 'auto',
  hideInProduction = true,
  customIcon,
  title = 'Dev',
  width = '280px',
  maxHeight = '240px',
}) => {
  const [isCollapsed, setIsCollapsed] = useState(true);
  const [activeTab, setActiveTab] = useState(defaultTab || tabs[0]?.id || '');
  
  // Hide in production if specified
  if (hideInProduction && process.env.NODE_ENV !== 'development') {
    return null;
  }
  
  // Position classes
  const positionClasses = {
    'bottom-right': 'bottom-3 right-3',
    'bottom-left': 'bottom-3 left-3',
    'top-right': 'top-3 right-3',
    'top-left': 'top-3 left-3',
  };
  
  // Theme classes
  const themeClasses = theme === 'light' 
    ? 'bg-white border-gray-300 text-gray-900'
    : 'bg-gray-900/95 dark:bg-black/95 border-gray-700/50 dark:border-gray-800 text-white';
  
  const activeTabContent = tabs.find(tab => tab.id === activeTab);
  
  return (
    <>
      {/* Bug button - always visible */}
      <button
        onClick={() => setIsCollapsed(!isCollapsed)}
        className={`fixed ${positionClasses[position].split(' ')[0]} ${positionClasses[position].split(' ')[1]} 
                   w-8 h-8 rounded-full
                   ${theme === 'light' ? 'bg-white' : 'bg-gray-900 dark:bg-black'}
                   backdrop-blur-sm
                   border ${theme === 'light' ? 'border-gray-300' : 'border-gray-700 dark:border-gray-800'}
                   shadow-lg shadow-black/50
                   flex items-center justify-center
                   ${theme === 'light' ? 'text-gray-900 hover:bg-gray-100' : 'text-white hover:bg-gray-800'}
                   transition-all duration-300
                   hover:scale-110 active:scale-95
                   z-[9999] ${className}`}
        title={isCollapsed ? `Show ${title.toLowerCase()} toolbar` : `Hide ${title.toLowerCase()} toolbar`}
      >
        {customIcon || (
          <Bug className={`w-4 h-4 transition-transform duration-300 ${
            isCollapsed ? '' : 'rotate-180'
          }`} />
        )}
      </button>
      
      {/* Dev toolbar panel */}
      {!isCollapsed && (
        <div className={`fixed ${positionClasses[position]} rounded
                        ${themeClasses}
                        backdrop-blur-sm
                        border
                        shadow-2xl shadow-black/50
                        z-[9998]
                        overflow-hidden
                        flex flex-col ${className}`}
             style={{ width, maxHeight }}>
          {/* Header */}
          <div className={`flex items-center justify-between px-2 py-1 border-b ${
            theme === 'light' ? 'border-gray-300' : 'border-gray-700/50'
          }`}>
            <div className="flex items-center gap-1">
              {customIcon || <Bug className={`w-3 h-3 ${theme === 'light' ? 'text-gray-600' : 'text-gray-400'}`} />}
              <h3 className={`font-medium text-[10px] ${
                theme === 'light' ? 'text-gray-900' : 'text-white'
              }`}>{title}</h3>
            </div>
            <button
              onClick={() => setIsCollapsed(true)}
              className={`${
                theme === 'light' ? 'text-gray-600 hover:text-gray-900' : 'text-gray-400 hover:text-white'
              } transition-colors`}
            >
              <X className="w-3 h-3" />
            </button>
          </div>
          
          {/* Tabs */}
          {tabs.length > 1 && (
            <div className={`flex border-b ${theme === 'light' ? 'border-gray-300' : 'border-gray-700/50'}`}>
              {tabs.map(({ id, icon: Icon }) => (
                <button
                  key={id}
                  onClick={() => setActiveTab(id)}
                  className={`flex-1 px-1 py-0.5 text-[10px] font-medium transition-colors
                    ${activeTab === id
                      ? theme === 'light'
                        ? 'bg-gray-100 text-gray-900 border-b-2 border-blue-500'
                        : 'bg-gray-800 text-white border-b-2 border-red-500'
                      : theme === 'light'
                        ? 'text-gray-600 hover:text-gray-900 hover:bg-gray-50'
                        : 'text-gray-400 hover:text-white hover:bg-gray-800/50'
                    }`}
                >
                  <Icon className="w-2.5 h-2.5 mx-auto" />
                </button>
              ))}
            </div>
          )}
          
          {/* Content */}
          <div className="flex-1 overflow-auto p-2">
            {activeTabContent && (
              typeof activeTabContent.content === 'function' 
                ? activeTabContent.content() 
                : activeTabContent.content
            )}
          </div>
        </div>
      )}
    </>
  );
};

// Export a simple hook for creating toolbar tabs
export const useDevToolbarTab = (
  id: string,
  label: string,
  icon: LucideIcon,
  content: ReactNode | (() => ReactNode)
): DevToolbarTab => {
  return { id, label, icon, content };
};

// Export utility components for consistent styling
export const DevToolbarSection: React.FC<{ 
  title?: string; 
  children: ReactNode;
  className?: string;
}> = ({ title, children, className = '' }) => (
  <div className={`space-y-2 ${className}`}>
    {title && (
      <div className="text-[10px] font-mono font-semibold text-gray-400 uppercase">
        {title}
      </div>
    )}
    {children}
  </div>
);

export const DevToolbarButton: React.FC<{
  onClick: () => void;
  variant?: 'default' | 'success' | 'warning' | 'danger';
  size?: 'sm' | 'xs';
  children: ReactNode;
  className?: string;
}> = ({ onClick, variant = 'default', size = 'xs', children, className = '' }) => {
  const variants = {
    default: 'bg-gray-800 hover:bg-gray-700',
    success: 'bg-green-800 hover:bg-green-700',
    warning: 'bg-yellow-800 hover:bg-yellow-700',
    danger: 'bg-red-800 hover:bg-red-700',
  };
  
  const sizes = {
    xs: 'px-1.5 py-0.5 text-[10px]',
    sm: 'px-2 py-1 text-[11px]',
  };
  
  return (
    <button
      onClick={onClick}
      className={`${variants[variant]} ${sizes[size]} text-white rounded
                 transition-colors ${className}`}
    >
      {children}
    </button>
  );
};

export const DevToolbarInfo: React.FC<{
  label: string;
  value: string | number | boolean;
  className?: string;
}> = ({ label, value, className = '' }) => (
  <div className={`text-[10px] font-mono text-gray-300 ${className}`}>
    <span className="text-gray-500">{label}:</span> {String(value)}
  </div>
);