import { getCurrentWebviewWindow } from '@tauri-apps/api/webviewWindow';
import { invoke } from '@tauri-apps/api/core';
import { useTimerStore } from '../stores/timer-store';
import { SessionTypeIndicator } from './SessionTypeIndicator';
import { LogicalSize } from '@tauri-apps/api/window';

interface CustomTitleBarProps {
  isCollapsed?: boolean;
  title?: string;
  showCollapseButton?: boolean;
}

export function CustomTitleBar({ isCollapsed = false, title, showCollapseButton = true }: CustomTitleBarProps) {
  const sessionType = useTimerStore(state => state.sessionType);
  const appWindow = getCurrentWebviewWindow();

  const handleClose = async () => {
    try {
      await appWindow.close();
    } catch (error) {
      console.error('Failed to close window:', error);
    }
  };

  const handleMinimize = async () => {
    try {
      await appWindow.minimize();
    } catch (error) {
      console.error('Failed to minimize window:', error);
    }
  };

  const handleMiddleClick = async (e: React.MouseEvent) => {
    // Only handle middle click on non-button areas
    if (e.button === 1 && showCollapseButton && !(e.target as HTMLElement).closest('button')) {
      e.preventDefault();
      try {
        await invoke('toggle_collapse');
      } catch (error) {
        console.error('Failed to toggle collapse:', error);
      }
    }
  };

  return (
    <div 
      className="h-7 flex items-center justify-between px-3 border-b border-border/30"
      data-tauri-drag-region
      style={{ 
        userSelect: 'none', 
        WebkitUserSelect: 'none',
        cursor: 'grab'
      }}
      onAuxClick={handleMiddleClick}
    >
      <div className="flex items-center gap-1.5">
        <button
          onClick={handleClose}
          className="w-3 h-3 rounded-full bg-red-500 hover:bg-red-600 transition-colors"
          aria-label="Close"
          data-tauri-drag-region="false"
        />
        <button
          onClick={handleMinimize}
          className="w-3 h-3 rounded-full bg-yellow-500 hover:bg-yellow-600 transition-colors"
          aria-label="Minimize"
          data-tauri-drag-region="false"
        />
        <div className="w-3 h-3 rounded-full bg-gray-600 cursor-not-allowed" />
      </div>
      
      <div className="flex items-center gap-2">
        {isCollapsed && (
          <SessionTypeIndicator type={sessionType} size="sm" />
        )}
        <span className="text-xs text-muted-foreground font-brand">
          {title || 'POMO'}
        </span>
      </div>
      
      <div className="flex items-center">
        {/* Empty space for symmetry */}
      </div>
    </div>
  );
}