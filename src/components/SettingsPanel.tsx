import { X, Volume2, Eye, Pin } from 'lucide-react';
import { useSettingsStore } from '../stores/settings-store';
import { useEffect } from 'react';

export function SettingsPanel() {
  const { 
    showSettings, 
    toggleSettings, 
    soundEnabled, 
    volume, 
    opacity,
    alwaysOnTop,
    updateSettings,
    loadSettings 
  } = useSettingsStore();
  
  useEffect(() => {
    loadSettings();
  }, [loadSettings]);
  
  if (!showSettings) return null;
  
  return (
    <div className="absolute inset-0 z-50 bg-black/50 backdrop-blur-sm rounded-[10px] animate-in fade-in duration-200">
      <div className="absolute inset-4 bg-background/95 rounded-lg border border-border/50 shadow-2xl animate-in slide-in-from-bottom-2 duration-300">
        <div className="flex items-center justify-between p-4 border-b border-border/50">
          <h2 className="text-lg font-medium">Settings</h2>
          <button
            onClick={toggleSettings}
            className="p-1.5 hover:bg-white/10 rounded-lg transition-colors"
            aria-label="Close settings"
          >
            <X className="w-4 h-4" />
          </button>
        </div>
        
        <div className="p-4 space-y-4">
          {/* Sound Settings */}
          <div className="space-y-2">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <Volume2 className="w-4 h-4 text-muted-foreground" />
                <span className="text-sm">Sound</span>
              </div>
              <button
                onClick={() => updateSettings({ soundEnabled: !soundEnabled })}
                className={`relative w-10 h-6 rounded-full transition-colors ${
                  soundEnabled ? 'bg-primary' : 'bg-secondary'
                }`}
              >
                <div className={`absolute top-1 w-4 h-4 bg-white rounded-full transition-transform ${
                  soundEnabled ? 'translate-x-5' : 'translate-x-1'
                }`} />
              </button>
            </div>
            
            {soundEnabled && (
              <div className="flex items-center gap-2 pl-6">
                <span className="text-xs text-muted-foreground">Volume</span>
                <input
                  type="range"
                  min="0"
                  max="100"
                  value={volume * 100}
                  onChange={(e) => updateSettings({ volume: Number(e.target.value) / 100 })}
                  className="flex-1 h-1 bg-secondary rounded-full appearance-none cursor-pointer [&::-webkit-slider-thumb]:appearance-none [&::-webkit-slider-thumb]:w-3 [&::-webkit-slider-thumb]:h-3 [&::-webkit-slider-thumb]:bg-primary [&::-webkit-slider-thumb]:rounded-full [&::-webkit-slider-thumb]:cursor-pointer"
                />
                <span className="text-xs text-muted-foreground w-8">{Math.round(volume * 100)}%</span>
              </div>
            )}
          </div>
          
          {/* Window Opacity */}
          <div className="space-y-2">
            <div className="flex items-center gap-2">
              <Eye className="w-4 h-4 text-muted-foreground" />
              <span className="text-sm">Window Opacity</span>
            </div>
            <div className="flex items-center gap-2 pl-6">
              <input
                type="range"
                min="50"
                max="100"
                value={opacity * 100}
                onChange={(e) => updateSettings({ opacity: Number(e.target.value) / 100 })}
                className="flex-1 h-1 bg-secondary rounded-full appearance-none cursor-pointer [&::-webkit-slider-thumb]:appearance-none [&::-webkit-slider-thumb]:w-3 [&::-webkit-slider-thumb]:h-3 [&::-webkit-slider-thumb]:bg-primary [&::-webkit-slider-thumb]:rounded-full [&::-webkit-slider-thumb]:cursor-pointer"
              />
              <span className="text-xs text-muted-foreground w-8">{Math.round(opacity * 100)}%</span>
            </div>
          </div>
          
          {/* Always on Top */}
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <Pin className="w-4 h-4 text-muted-foreground" />
              <span className="text-sm">Always on Top</span>
            </div>
            <button
              onClick={() => updateSettings({ alwaysOnTop: !alwaysOnTop })}
              className={`relative w-10 h-6 rounded-full transition-colors ${
                alwaysOnTop ? 'bg-primary' : 'bg-secondary'
              }`}
            >
              <div className={`absolute top-1 w-4 h-4 bg-white rounded-full transition-transform ${
                alwaysOnTop ? 'translate-x-5' : 'translate-x-1'
              }`} />
            </button>
          </div>
          
          {/* Shortcuts Info */}
          <div className="pt-4 border-t border-border/50">
            <p className="text-xs text-muted-foreground">
              <kbd className="px-1.5 py-0.5 text-xs bg-secondary rounded">Hyperkey+P</kbd> to toggle window
            </p>
            <p className="text-xs text-muted-foreground mt-1">
              <kbd className="px-1.5 py-0.5 text-xs bg-secondary rounded">Middle-click</kbd> title bar to collapse
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}