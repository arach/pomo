import { getCurrentWebviewWindow } from '@tauri-apps/api/webviewWindow';
import { invoke } from '@tauri-apps/api/core';

interface CustomTitleBarProps {
  isCollapsed?: boolean;
  title?: string;
  showCollapseButton?: boolean;
}

export function CustomTitleBar({ isCollapsed = false, title, showCollapseButton = true }: CustomTitleBarProps) {
  const appWindow = getCurrentWebviewWindow();

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
      
      <span className="text-xs text-muted-foreground">
        {title || (isCollapsed ? 'Pomo' : 'Pomodoro Timer')}
      </span>
      
      <div className="w-[54px]" />
    </div>
  );
}