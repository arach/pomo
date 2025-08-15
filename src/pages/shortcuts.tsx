import React from 'react';
import ReactDOM from 'react-dom/client';
import { WindowWrapper } from '../components/WindowWrapper';
import { CustomTitleBar } from '../components/CustomTitleBar';
import '../index.css';

interface ShortcutGroup {
  title: string;
  shortcuts: Array<{
    keys: string[];
    description: string;
  }>;
}

function ShortcutsWindow() {
  const shortcutGroups: ShortcutGroup[] = [
    {
      title: 'Timer Controls',
      shortcuts: [
        { keys: ['S'], description: 'Start timer' },
        { keys: ['Space'], description: 'Pause/Resume timer' },
        { keys: ['R'], description: 'Reset timer' },
        { keys: ['Esc'], description: 'Stop timer' },
        { keys: ['D'], description: 'Open duration panel' },
        { keys: ['N'], description: 'Name session' },
      ]
    },
    {
      title: 'Navigation',
      shortcuts: [
        { keys: ['⌘', ','], description: 'Open settings' },
        { keys: ['⌘', 'T'], description: 'Toggle always on top' },
        { keys: ['1-9'], description: 'Quick set minutes (5-45)' },
        { keys: ['↑', '↓'], description: 'Adjust duration ±1 minute' },
        { keys: ['Shift', '↑/↓'], description: 'Adjust duration ±5 minutes' },
      ]
    },
    {
      title: 'Interface',
      shortcuts: [
        { keys: ['?'], description: 'Toggle this help' },
        { keys: ['H'], description: 'Hide/Show window' },
        { keys: ['M'], description: 'Toggle mute' },
        { keys: ['T'], description: 'Cycle through themes' },
        { keys: ['C'], description: 'Cycle session types' },
      ]
    }
  ];

  // Close window on Escape or ?
  React.useEffect(() => {
    const handleKeyPress = async (e: KeyboardEvent) => {
      if (e.key === 'Escape' || e.key === '?') {
        e.preventDefault();
        try {
          // Import Tauri window API dynamically
          const { getCurrentWindow } = await import('@tauri-apps/api/window');
          await getCurrentWindow().close();
        } catch (error) {
          console.error('Failed to close window:', error);
        }
      }
    };
    
    window.addEventListener('keydown', handleKeyPress);
    return () => window.removeEventListener('keydown', handleKeyPress);
  }, []);

  return (
    <WindowWrapper>
      <CustomTitleBar />
      <div className="flex flex-col h-full bg-gray-900 pt-7">
        <div className="px-6 py-4 border-b border-gray-800">
          <h2 className="text-xl font-semibold text-white">Keyboard Shortcuts</h2>
          <p className="text-sm text-gray-400 mt-1">Press ? or Esc to close</p>
        </div>
        
        <div className="flex-1 p-6 overflow-y-auto">
          <div className="grid grid-cols-2 gap-6 max-w-4xl mx-auto">
            {shortcutGroups.map((group, groupIdx) => (
              <div key={group.title} className={groupIdx === shortcutGroups.length - 1 ? "col-span-2" : ""}>
                <h3 className="text-sm font-medium text-gray-300 mb-3 uppercase tracking-wider">{group.title}</h3>
                <div className="space-y-1">
                  {group.shortcuts.map((shortcut, idx) => (
                    <div key={idx} className="flex items-center justify-between py-1.5 px-3 rounded bg-gray-800/30 hover:bg-gray-800/50 transition-colors">
                      <div className="flex items-center gap-1">
                        {shortcut.keys.map((key, kidx) => (
                          <React.Fragment key={kidx}>
                            {kidx > 0 && <span className="text-gray-500 text-xs mx-1">+</span>}
                            <kbd className="px-1.5 py-0.5 text-xs font-semibold text-gray-300 bg-gray-700 border border-gray-600 rounded shadow-sm">
                              {key}
                            </kbd>
                          </React.Fragment>
                        ))}
                      </div>
                      <span className="text-sm text-gray-400 ml-4">{shortcut.description}</span>
                    </div>
                  ))}
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </WindowWrapper>
  );
}

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <ShortcutsWindow />
  </React.StrictMode>
);