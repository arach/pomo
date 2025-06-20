import { useState, useEffect } from 'react';
import { useTimerStore } from '../stores/timer-store';

interface SessionNameInputProps {
  onDismiss?: () => void;
}

export function SessionNameInput({ onDismiss }: SessionNameInputProps) {
  const { sessionName, setSessionName } = useTimerStore();
  const [value, setValue] = useState(sessionName || '');
  const [isVisible, setIsVisible] = useState(false);

  useEffect(() => {
    setIsVisible(true);
  }, []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    const name = value.trim() || null;
    await setSessionName(name);
    onDismiss?.();
  };

  const handleCancel = () => {
    setValue(sessionName || '');
    onDismiss?.();
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Escape') {
      handleCancel();
    }
  };

  return (
    <div 
      className={`fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center transition-opacity duration-200 ${
        isVisible ? 'opacity-100' : 'opacity-0'
      }`}
      onClick={handleCancel}
    >
      <div 
        className="bg-background/95 backdrop-blur-md border border-border/30 rounded-lg p-6 w-80 shadow-2xl"
        onClick={(e) => e.stopPropagation()}
      >
        <h3 className="text-lg font-brand mb-4">Name This Session</h3>
        <form onSubmit={handleSubmit}>
          <input
            type="text"
            value={value}
            onChange={(e) => setValue(e.target.value)}
            onKeyDown={handleKeyDown}
            placeholder="Session name (optional)"
            className="w-full px-3 py-2 bg-muted/20 border border-border/30 rounded text-sm focus:outline-none focus:ring-2 focus:ring-primary/50 mb-4"
            autoFocus
            maxLength={50}
          />
          <div className="flex gap-2 justify-end">
            <button
              type="button"
              onClick={handleCancel}
              className="px-3 py-1.5 text-sm text-muted-foreground hover:text-foreground transition-colors"
            >
              Cancel
            </button>
            <button
              type="submit"
              className="px-3 py-1.5 text-sm bg-primary/20 hover:bg-primary/30 rounded transition-colors"
            >
              Save
            </button>
          </div>
        </form>
        <div className="mt-3 text-xs text-muted-foreground">
          Press <kbd className="px-1 py-0.5 bg-muted/30 rounded text-xs">Escape</kbd> to cancel or leave empty to remove name
        </div>
      </div>
    </div>
  );
}