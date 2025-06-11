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
  const appWindow = getCurrentWebviewWindow();
  const sessionType = useTimerStore(state => state.sessionType);

  const handleClose = async () => {
    await appWindow.close();
  };

  const handleMinimize = async () => {
    await appWindow.minimize();
  };

  const handleMiddleClick = async (e: React.MouseEvent) => {
    if (e.button === 1 && showCollapseButton) {
      e.preventDefault();
      await invoke('toggle_collapse');
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
      onMouseDown={handleMiddleClick}
    >
      <div className="flex items-center gap-1.5">
        <button
          onClick={handleClose}
          className="w-3 h-3 rounded-full bg-red-500 hover:bg-red-600 transition-colors"
          aria-label="Close"
        />
        <button
          onClick={handleMinimize}
          className="w-3 h-3 rounded-full bg-yellow-500 hover:bg-yellow-600 transition-colors"
          aria-label="Minimize"
        />
        <div className="w-3 h-3 rounded-full bg-gray-600 cursor-not-allowed" />
      </div>
      
      <div className="flex items-center gap-2">
        {isCollapsed && (
          <SessionTypeIndicator type={sessionType} size="sm" />
        )}
        <span className="text-xs text-muted-foreground">
          {title || 'Pomo'}
        </span>
      </div>
      
      <div className="flex items-center">
        {/* Reset window size button - only in dev mode */}
        {import.meta.env.DEV && (
          <button
            onClick={async () => {
              await appWindow.setSize(new LogicalSize(320, 280));
              await appWindow.center();
            }}
            className="text-[10px] px-1.5 py-0.5 rounded bg-muted/20 hover:bg-muted/30 text-muted-foreground transition-colors"
            title="Reset window size"
          >
            Reset
          </button>
        )}
      </div>
    </div>
  );
}