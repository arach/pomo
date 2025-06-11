import React from 'react';

interface KeyboardShortcutsProps {
  isOpen: boolean;
  onClose: () => void;
}

interface ShortcutGroup {
  title: string;
  shortcuts: Array<{
    keys: string[];
    description: string;
  }>;
}

export function KeyboardShortcuts({ isOpen, onClose }: KeyboardShortcutsProps) {
  if (!isOpen) return null;

  const shortcutGroups: ShortcutGroup[] = [
    {
      title: 'Timer Controls',
      shortcuts: [
        { keys: ['S'], description: 'Start timer' },
        { keys: ['Space'], description: 'Pause/Resume timer' },
        { keys: ['R'], description: 'Reset timer' },
        { keys: ['Esc'], description: 'Stop timer' },
      ]
    },
    {
      title: 'Navigation',
      shortcuts: [
        { keys: ['⌘', ','], description: 'Open settings' },
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
      ]
    }
  ];

  // Handle escape key to close
  React.useEffect(() => {
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape' || e.key === '?') {
        onClose();
      }
    };
    
    if (isOpen) {
      window.addEventListener('keydown', handleEscape);
      return () => window.removeEventListener('keydown', handleEscape);
    }
  }, [isOpen, onClose]);

  return (
    <div 
      className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4"
      onClick={onClose}
    >
      <div 
        className="bg-gray-900 rounded-lg shadow-2xl max-w-2xl w-full max-h-[80vh] overflow-hidden border border-gray-800"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="p-6 border-b border-gray-800">
          <h2 className="text-xl font-semibold text-white">Keyboard Shortcuts</h2>
          <p className="text-sm text-gray-400 mt-1">Press ? or Esc to close</p>
        </div>
        
        <div className="p-6 overflow-y-auto max-h-[60vh]">
          <div className="grid gap-6">
            {shortcutGroups.map((group) => (
              <div key={group.title}>
                <h3 className="text-sm font-medium text-gray-300 mb-3">{group.title}</h3>
                <div className="space-y-2">
                  {group.shortcuts.map((shortcut, idx) => (
                    <div key={idx} className="flex items-center justify-between py-1">
                      <div className="flex items-center gap-1">
                        {shortcut.keys.map((key, kidx) => (
                          <React.Fragment key={kidx}>
                            {kidx > 0 && <span className="text-gray-600 text-xs">+</span>}
                            <kbd className="px-2 py-1 text-xs font-semibold text-gray-300 bg-gray-800 border border-gray-700 rounded">
                              {key}
                            </kbd>
                          </React.Fragment>
                        ))}
                      </div>
                      <span className="text-sm text-gray-400">{shortcut.description}</span>
                    </div>
                  ))}
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}