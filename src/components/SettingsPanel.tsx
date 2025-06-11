import { X, Volume2, Eye, Pin, Keyboard, Music, Watch, Upload } from 'lucide-react';
import { useSettingsStore } from '../stores/settings-store';
import { useEffect, useState } from 'react';
import { WatchFaceLoader } from '../services/watchface-loader';
import { open } from '@tauri-apps/plugin-dialog';
import { readTextFile } from '@tauri-apps/plugin-fs';

const SOUND_OPTIONS = [
  { value: 'default', label: 'Default Beep', preview: '🔔' },
  { value: 'bell', label: 'Bell', preview: '🔔' },
  { value: 'chime', label: 'Chime', preview: '🎵' },
  { value: 'ding', label: 'Ding', preview: '🛎️' },
  { value: 'custom', label: 'Custom File...', preview: '📁' },
];

const MODIFIER_KEYS = [
  { value: 'Super', label: '⌘ Cmd', mac: '⌘', windows: '⊞ Win' },
  { value: 'Control', label: 'Ctrl', mac: '⌃', windows: 'Ctrl' },
  { value: 'Alt', label: 'Alt', mac: '⌥', windows: 'Alt' },
  { value: 'Shift', label: 'Shift', mac: '⇧', windows: 'Shift' },
];

interface SettingsPanelProps {
  isStandalone?: boolean;
}

export function SettingsPanel({ isStandalone = false }: SettingsPanelProps) {
  const { 
    showSettings, 
    toggleSettings, 
    soundEnabled, 
    volume, 
    opacity,
    alwaysOnTop,
    notificationSound,
    customShortcut,
    watchFace,
    updateSettings,
    loadSettings 
  } = useSettingsStore();
  
  const [selectedModifiers, setSelectedModifiers] = useState<string[]>(customShortcut.modifiers);
  const [selectedKey, setSelectedKey] = useState(customShortcut.key);
  const [isRecordingShortcut, setIsRecordingShortcut] = useState(false);
  const [availableWatchFaces, setAvailableWatchFaces] = useState<Array<{ id: string; name: string; description?: string }>>([]);
  
  useEffect(() => {
    loadSettings();
    // Load available watch faces
    const loadWatchFaces = async () => {
      await WatchFaceLoader.loadBuiltInFaces();
      await WatchFaceLoader.loadCustomFacesFromStorage();
      const faces = WatchFaceLoader.getAllWatchFaces();
      setAvailableWatchFaces(faces.map(f => ({ 
        id: f.id, 
        name: f.name, 
        description: f.description 
      })));
    };
    loadWatchFaces();
  }, [loadSettings]);
  
  useEffect(() => {
    if (isRecordingShortcut) {
      const handleKeyDown = (e: KeyboardEvent) => {
        e.preventDefault();
        
        // Get modifiers
        const modifiers: string[] = [];
        if (e.metaKey) modifiers.push('Super');
        if (e.ctrlKey) modifiers.push('Control');
        if (e.altKey) modifiers.push('Alt');
        if (e.shiftKey) modifiers.push('Shift');
        
        // Get the key (excluding modifier keys)
        const key = e.key.toUpperCase();
        if (!['META', 'CONTROL', 'ALT', 'SHIFT'].includes(key)) {
          setSelectedModifiers(modifiers);
          setSelectedKey(key);
          setIsRecordingShortcut(false);
          
          // Update the shortcut
          updateSettings({
            customShortcut: {
              toggleVisibility: `${modifiers.join('+')}+${key}`,
              modifiers,
              key
            }
          });
        }
      };
      
      window.addEventListener('keydown', handleKeyDown);
      return () => window.removeEventListener('keydown', handleKeyDown);
    }
  }, [isRecordingShortcut, updateSettings]);
  
  const handleSoundPreview = () => {
    if (soundEnabled) {
      // Import and use AudioService to preview the selected sound
      import('../services/audio').then(({ AudioService }) => {
        AudioService.playCompletionSound(volume);
      });
    }
  };
  
  if (!isStandalone && !showSettings) return null;
  
  const content = (
    <>
      {!isStandalone && (
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
      )}
        
        <div className={`p-4 space-y-6 ${isStandalone ? 'h-[calc(100vh-40px)]' : 'max-h-[calc(100vh-8rem)]'} overflow-y-auto`}>
          {/* Sound Settings */}
          <div className="space-y-3">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <Volume2 className="w-4 h-4 text-muted-foreground" />
                <span className="text-sm font-medium">Sound</span>
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
              <>
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
                
                <div className="pl-6 space-y-2">
                  <div className="flex items-center gap-2">
                    <Music className="w-3 h-3 text-muted-foreground" />
                    <span className="text-xs text-muted-foreground">Notification Sound</span>
                  </div>
                  <div className="grid grid-cols-2 gap-2">
                    {SOUND_OPTIONS.map((sound) => (
                      <button
                        key={sound.value}
                        onClick={() => {
                          updateSettings({ notificationSound: sound.value });
                          handleSoundPreview();
                        }}
                        className={`flex items-center gap-2 px-3 py-2 rounded-lg text-sm transition-all ${
                          notificationSound === sound.value
                            ? 'bg-primary text-primary-foreground'
                            : 'bg-secondary hover:bg-secondary/80'
                        }`}
                      >
                        <span>{sound.preview}</span>
                        <span className="text-xs">{sound.label}</span>
                      </button>
                    ))}
                  </div>
                </div>
              </>
            )}
          </div>
          
          {/* Window Settings */}
          <div className="space-y-3">
            <div className="space-y-2">
              <div className="flex items-center gap-2">
                <Eye className="w-4 h-4 text-muted-foreground" />
                <span className="text-sm font-medium">Window Opacity</span>
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
            
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <Pin className="w-4 h-4 text-muted-foreground" />
                <span className="text-sm font-medium">Always on Top</span>
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
          </div>
          
          {/* Keyboard Shortcuts */}
          <div className="space-y-3">
            <div className="flex items-center gap-2">
              <Keyboard className="w-4 h-4 text-muted-foreground" />
              <span className="text-sm font-medium">Keyboard Shortcut</span>
            </div>
            
            <div className="pl-6 space-y-3">
              <div className="flex items-center gap-2">
                <span className="text-xs text-muted-foreground">Toggle Window:</span>
                <button
                  onClick={() => setIsRecordingShortcut(true)}
                  className={`px-3 py-1.5 rounded-lg text-xs font-mono transition-all ${
                    isRecordingShortcut
                      ? 'bg-primary text-primary-foreground animate-pulse'
                      : 'bg-secondary hover:bg-secondary/80'
                  }`}
                >
                  {isRecordingShortcut ? (
                    'Press keys...'
                  ) : (
                    <>
                      {selectedModifiers.map(mod => (
                        <span key={mod}>
                          {MODIFIER_KEYS.find(m => m.value === mod)?.mac || mod}
                        </span>
                      )).reduce((prev, curr, i) => 
                        i === 0 ? [curr] : [...prev, '+', curr], [] as React.ReactNode[]
                      )}
                      {selectedModifiers.length > 0 && '+'}
                      {selectedKey}
                    </>
                  )}
                </button>
              </div>
              
              <p className="text-xs text-muted-foreground">
                Click the button and press your desired key combination
              </p>
            </div>
          </div>
          
          {/* Watch Face */}
          <div className="space-y-3">
            <div className="flex items-center gap-2">
              <Watch className="w-4 h-4 text-muted-foreground" />
              <span className="text-sm font-medium">Watch Face</span>
            </div>
            
            <div className="pl-6">
              <div className="grid grid-cols-3 gap-2">
                {availableWatchFaces.map((face) => (
                  <button
                    key={face.id}
                    onClick={() => updateSettings({ watchFace: face.id })}
                    className={`relative flex flex-col gap-1 p-2 rounded-lg transition-all ${
                      watchFace === face.id
                        ? 'ring-2 ring-primary bg-primary/10'
                        : 'bg-secondary hover:bg-secondary/80'
                    }`}
                  >
                    <div className="aspect-[3/2] bg-black/20 rounded-md flex items-center justify-center overflow-hidden relative">
                      <div className="watchface-preview" data-face={face.id}>
                        {/* Preview representations */}
                        {face.id === 'default' && (
                          <div className="relative">
                            <div className="w-8 h-8 rounded-full border-2 border-blue-500 relative">
                              <div className="absolute inset-0 rounded-full" style={{
                                background: `conic-gradient(from 0deg, #3b82f6 0deg 120deg, transparent 120deg 360deg)`
                              }} />
                            </div>
                            <div className="absolute inset-0 flex items-center justify-center text-xs text-white font-mono">25</div>
                          </div>
                        )}
                        {face.id === 'chronograph' && (
                          <div className="relative">
                            <div className="w-8 h-8 rounded-full border-2 border-gradient-to-r from-blue-400 to-purple-500 relative bg-gradient-to-br from-blue-500 to-purple-600">
                              <div className="absolute inset-0 rounded-full border border-white/20" />
                            </div>
                            <div className="absolute inset-0 flex items-center justify-center text-xs text-white font-mono">25</div>
                          </div>
                        )}
                        {face.id === 'terminal' && (
                          <div className="bg-black/90 p-2 rounded text-green-400 font-mono text-xs">
                            <div>$ pomo --duration=25m</div>
                            <div className="text-center">25:00</div>
                            <div className="text-center">████████████</div>
                          </div>
                        )}
                        {face.id === 'retro-digital' && (
                          <div className="bg-gray-900 border border-green-400 p-2 rounded text-green-400 font-mono text-xs text-center">
                            <div className="text-lg font-bold" style={{ textShadow: '0 0 5px currentColor' }}>25:00</div>
                            <div className="mt-1 bg-green-400 h-1 rounded"></div>
                          </div>
                        )}
                        {face.id === 'minimal' && (
                          <div className="text-center bg-background/80 backdrop-blur-sm border border-border/20 rounded p-2">
                            <div className="text-lg font-light text-foreground">25:00</div>
                            <div className="w-12 h-0.5 bg-muted mx-auto mt-1"></div>
                          </div>
                        )}
                        {face.id === 'neon' && (
                          <div className="relative">
                            <div className="w-8 h-8 rounded-full border-2 border-pink-500 relative" style={{
                              boxShadow: '0 0 10px #ff00ff'
                            }}>
                              <div className="absolute inset-1 rounded-full border border-cyan-400" style={{
                                boxShadow: '0 0 5px #00ffff'
                              }} />
                            </div>
                            <div className="absolute inset-0 flex items-center justify-center text-xs text-pink-500 font-bold" style={{
                              textShadow: '0 0 5px currentColor'
                            }}>25</div>
                          </div>
                        )}
                        {face.id.startsWith('custom_') && (
                          <div className="text-xs text-muted-foreground flex flex-col items-center">
                            <div className="text-lg">✦</div>
                            <div>Custom</div>
                          </div>
                        )}
                      </div>
                    </div>
                    <div className="text-left">
                      <span className="text-xs font-medium block truncate">{face.name}</span>
                      {watchFace === face.id && (
                        <span className="text-xs text-primary">Active</span>
                      )}
                    </div>
                  </button>
                ))}
              
                <button
                  onClick={async () => {
                    try {
                      const selected = await open({
                        multiple: false,
                        filters: [{
                          name: 'Watch Face',
                          extensions: ['json']
                        }]
                      });
                      
                      if (selected && typeof selected === 'string') {
                        // Read the file content
                        const content = await readTextFile(selected);
                        const config = JSON.parse(content);
                        
                        // Validate and load the watchface
                        if (!WatchFaceLoader.validateWatchFace(config)) {
                          throw new Error('Invalid watch face configuration');
                        }
                        
                        await WatchFaceLoader.loadCustomFace(config);
                        
                        // Refresh available watch faces
                        const faces = WatchFaceLoader.getAllWatchFaces();
                        setAvailableWatchFaces(faces.map(f => ({ 
                          id: f.id, 
                          name: f.name, 
                          description: f.description 
                        })));
                        
                        // Select the newly loaded face (with custom_ prefix)
                        updateSettings({ watchFace: `custom_${config.id}` });
                        
                        // Save custom faces to storage
                        await WatchFaceLoader.saveCustomFacesToStorage();
                      }
                    } catch (error) {
                      console.error('Failed to load watch face:', error);
                      alert(`Failed to load watch face: ${error}`);
                    }
                  }}
                  className="col-span-3 flex items-center justify-center gap-2 px-3 py-3 mt-2 rounded-lg bg-secondary hover:bg-secondary/80 transition-all border-2 border-dashed border-border"
                >
                  <Upload className="w-4 h-4" />
                  <span className="text-sm">Load Custom Watch Face</span>
                </button>
              </div>
            </div>
          </div>
          
          {/* Info */}
          <div className="pt-4 border-t border-border/50 space-y-1">
            <p className="text-xs text-muted-foreground">
              <kbd className="px-1.5 py-0.5 text-xs bg-secondary rounded">Middle-click</kbd> title bar to collapse
            </p>
            <p className="text-xs text-muted-foreground">
              Drag the title bar to move the window
            </p>
          </div>
        </div>
    </>
  );
  
  if (isStandalone) {
    return content;
  }
  
  return (
    <div className="absolute inset-0 z-50 bg-black/50 backdrop-blur-sm rounded-[10px] animate-in fade-in duration-200">
      <div className="absolute inset-4 bg-background/95 rounded-lg border border-border/50 shadow-2xl animate-in slide-in-from-bottom-2 duration-300">
        {content}
      </div>
    </div>
  );
}