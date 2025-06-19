import { TimerDisplay } from '../TimerDisplay';
import { WindowWrapper } from '../WindowWrapper';
import { CustomTitleBar } from '../CustomTitleBar';
import { useTimerStore } from '../../stores/timer-store';
import { useSettingsStore } from '../../stores/settings-store';
import { useState, useEffect, useCallback } from 'react';

// Import analysis files as raw text
import defaultAnalysis from '../../../watchface-analysis/default-clean-analysis.md?raw';
import rolodexAnalysis from '../../../watchface-analysis/rolodex-analysis.md?raw';
import terminalAnalysis from '../../../watchface-analysis/terminal-analysis.md?raw';
import retrolcdAnalysis from '../../../watchface-analysis/retro-lcd-analysis.md?raw';
import neonAnalysis from '../../../watchface-analysis/neon-watchface-analysis.md?raw';

const WATCHFACES = [
  { id: 'default', name: 'Default' },
  { id: 'rolodex', name: 'Rolodex' },
  { id: 'terminal', name: 'Terminal' },
  { id: 'retro-digital', name: 'Retro Digital' },
  { id: 'retro-lcd', name: 'Retro LCD' },
  { id: 'neon', name: 'Neon' }
];

const ANALYSIS_CONTENT: Record<string, string> = {
  'default': defaultAnalysis,
  'rolodex': rolodexAnalysis,
  'terminal': terminalAnalysis,
  'retro-digital': 'No analysis available for this watchface yet.',
  'retro-lcd': retrolcdAnalysis,
  'neon': neonAnalysis,
};

export function SplitViewComparison() {
  const [showDurationInput, setShowDurationInput] = useState(false);
  const { isRunning, isPaused, start, pause, reset } = useTimerStore();
  const { watchFace: settingsWatchFace } = useSettingsStore();
  
  // Check URL params for watchface override
  const urlParams = new URLSearchParams(window.location.search);
  const urlWatchFace = urlParams.get('watchface');
  const initialWatchFace = urlWatchFace || settingsWatchFace;
  const [selectedWatchFace, setSelectedWatchFace] = useState(initialWatchFace);
  const [showAnalysisPanel, setShowAnalysisPanel] = useState(false);
  const [showShortcutsGuide, setShowShortcutsGuide] = useState(false);
  
  // Update URL when watchface changes
  const handleWatchFaceChange = (newWatchFace: string) => {
    setSelectedWatchFace(newWatchFace);
    const url = new URL(window.location.href);
    url.searchParams.set('watchface', newWatchFace);
    window.history.replaceState({}, '', url.toString());
  };
  
  // Cycle through themes
  const cycleTheme = useCallback((direction: 'next' | 'prev' = 'next') => {
    const currentIndex = WATCHFACES.findIndex(wf => wf.id === selectedWatchFace);
    let nextIndex;
    if (direction === 'next') {
      nextIndex = (currentIndex + 1) % WATCHFACES.length;
    } else {
      nextIndex = currentIndex === 0 ? WATCHFACES.length - 1 : currentIndex - 1;
    }
    handleWatchFaceChange(WATCHFACES[nextIndex].id);
  }, [selectedWatchFace]);

  // Keyboard shortcuts
  const handleKeyDown = useCallback((event: KeyboardEvent) => {
    // Don't handle shortcuts if user is typing in an input
    if (event.target instanceof HTMLInputElement || event.target instanceof HTMLTextAreaElement) {
      return;
    }

    const key = event.key.toLowerCase();
    const isCtrl = event.ctrlKey || event.metaKey;

    // Handle key combinations first
    if (isCtrl) {
      switch (key) {
        case ';':
          event.preventDefault();
          // TODO: Open settings window
          console.log('Open settings (Ctrl+;)');
          break;
      }
      return;
    }

    // Handle single key shortcuts
    switch (key) {
      case 's':
        event.preventDefault();
        if (!isRunning) {
          start();
          setShowDurationInput(false);
        }
        break;
      
      case 'p':
      case ' ': // Spacebar
        event.preventDefault();
        if (isRunning) {
          if (isPaused) {
            start();
          } else {
            pause();
          }
        }
        break;
      
      case 'r':
        event.preventDefault();
        reset();
        setShowDurationInput(true);
        break;
      
      case 't':
        event.preventDefault();
        if (event.shiftKey) {
          cycleTheme('prev');
        } else {
          cycleTheme('next');
        }
        break;
      
      case 'a':
        event.preventDefault();
        setShowAnalysisPanel(!showAnalysisPanel);
        break;
      
      case '?':
        event.preventDefault();
        setShowShortcutsGuide(!showShortcutsGuide);
        break;
      
      case 'escape':
        event.preventDefault();
        // Close any open panels
        if (showAnalysisPanel) setShowAnalysisPanel(false);
        if (showShortcutsGuide) setShowShortcutsGuide(false);
        break;

      // Number keys for quick theme switching
      case '1': case '2': case '3': case '4': case '5': case '6':
        event.preventDefault();
        const themeIndex = parseInt(key) - 1;
        if (themeIndex < WATCHFACES.length) {
          handleWatchFaceChange(WATCHFACES[themeIndex].id);
        }
        break;
    }
  }, [isRunning, isPaused, start, pause, reset, cycleTheme, showAnalysisPanel, showShortcutsGuide]);

  useEffect(() => {
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [handleKeyDown]);

  // Get analysis content for current watchface
  const analysisContent = ANALYSIS_CONTENT[selectedWatchFace] || 'No analysis available for this watchface.';
  const currentWatchfaceName = WATCHFACES.find(wf => wf.id === selectedWatchFace)?.name || selectedWatchFace;
  
  return (
    <div className="flex flex-col h-screen bg-black">
      {/* Main Split View */}
      <div className={`flex flex-1 min-h-0 transition-all duration-300 ${showAnalysisPanel ? 'pb-[300px]' : ''}`}>
        {/* Version 1 */}
        <div className="flex-1 relative border-r border-gray-800">
          <WindowWrapper>
            <CustomTitleBar isCollapsed={false} />
            <div className="absolute top-8 left-4 z-50 px-2 py-1 bg-blue-600 text-white text-xs rounded-md font-bold">
              v1
            </div>
            <div className="flex-1 flex flex-col min-h-0">
              <TimerDisplay 
                isCollapsed={false} 
                onTimeClick={() => !isRunning && setShowDurationInput(true)}
                showDurationInput={showDurationInput}
                version="v1"
              />
            </div>
          </WindowWrapper>
        </div>
        
        {/* Version 2 */}
        <div className="flex-1 relative">
          <WindowWrapper>
            <CustomTitleBar isCollapsed={false} />
            <div className="absolute top-8 left-4 z-50 px-2 py-1 bg-green-600 text-white text-xs rounded-md font-bold">
              v2
            </div>
            <div className="flex-1 flex flex-col min-h-0">
              <TimerDisplay 
                isCollapsed={false} 
                onTimeClick={() => !isRunning && setShowDurationInput(true)}
                showDurationInput={showDurationInput}
                version="v2"
              />
            </div>
          </WindowWrapper>
        </div>
      </div>
      
      {/* Analysis Panel */}
      {showAnalysisPanel && (
        <div className="fixed bottom-12 left-0 right-0 h-[300px] bg-gray-950/95 border-t border-gray-800 shadow-2xl z-40 animate-in slide-in-from-bottom duration-300">
          <div className="h-full flex flex-col">
            {/* Panel Header */}
            <div className="flex items-center justify-between px-4 py-2 border-b border-gray-800/50 bg-gray-900/50">
              <div className="flex items-center gap-2">
                <span className="text-sm font-medium text-gray-200">{currentWatchfaceName} Analysis</span>
                <span className="text-xs text-gray-500">V2 Improvements & Documentation</span>
              </div>
              <button
                onClick={() => setShowAnalysisPanel(false)}
                className="text-gray-400 hover:text-gray-200 text-sm px-2 py-1 rounded hover:bg-gray-800/50"
              >
                ✕
              </button>
            </div>
            
            {/* Panel Content */}
            <div className="flex-1 p-4 overflow-y-auto">
              <pre className="whitespace-pre-wrap font-mono text-xs leading-relaxed text-gray-300 bg-gray-900/30 p-4 rounded border border-gray-800/50">
                {analysisContent}
              </pre>
            </div>
          </div>
        </div>
      )}
      
      {/* Shortcuts Guide */}
      {showShortcutsGuide && (
        <>
          {/* Backdrop */}
          <div 
            className="fixed inset-0 bg-black/60 z-50 transition-opacity"
            onClick={() => setShowShortcutsGuide(false)}
          />
          
          {/* Modal */}
          <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
            <div className="bg-gray-900 border border-gray-700 rounded-lg shadow-2xl max-w-md w-full max-h-[80vh] overflow-hidden">
              {/* Header */}
              <div className="flex items-center justify-between p-4 border-b border-gray-700">
                <h3 className="text-lg font-semibold text-gray-100">Keyboard Shortcuts</h3>
                <button
                  onClick={() => setShowShortcutsGuide(false)}
                  className="text-gray-400 hover:text-gray-200 text-xl leading-none p-1"
                >
                  ✕
                </button>
              </div>
              
              {/* Content */}
              <div className="p-4 overflow-y-auto max-h-[calc(80vh-80px)]">
                <div className="space-y-4 text-sm">
                  {/* Timer Controls */}
                  <div>
                    <h4 className="text-gray-200 font-medium mb-2">Timer Controls</h4>
                    <div className="space-y-1 text-xs">
                      <div className="flex justify-between">
                        <span className="text-gray-400">Start timer</span>
                        <kbd className="bg-gray-800 px-1.5 py-0.5 rounded text-gray-300">S</kbd>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-gray-400">Pause/Resume</span>
                        <div className="space-x-1">
                          <kbd className="bg-gray-800 px-1.5 py-0.5 rounded text-gray-300">P</kbd>
                          <kbd className="bg-gray-800 px-1.5 py-0.5 rounded text-gray-300">Space</kbd>
                        </div>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-gray-400">Reset timer</span>
                        <kbd className="bg-gray-800 px-1.5 py-0.5 rounded text-gray-300">R</kbd>
                      </div>
                    </div>
                  </div>
                  
                  {/* Theme Controls */}
                  <div>
                    <h4 className="text-gray-200 font-medium mb-2">Themes</h4>
                    <div className="space-y-1 text-xs">
                      <div className="flex justify-between">
                        <span className="text-gray-400">Cycle theme</span>
                        <kbd className="bg-gray-800 px-1.5 py-0.5 rounded text-gray-300">T</kbd>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-gray-400">Reverse cycle</span>
                        <kbd className="bg-gray-800 px-1.5 py-0.5 rounded text-gray-300">Shift + T</kbd>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-gray-400">Quick select</span>
                        <div className="space-x-1">
                          <kbd className="bg-gray-800 px-1.5 py-0.5 rounded text-gray-300">1</kbd>
                          <kbd className="bg-gray-800 px-1.5 py-0.5 rounded text-gray-300">2</kbd>
                          <kbd className="bg-gray-800 px-1.5 py-0.5 rounded text-gray-300">3</kbd>
                          <span className="text-gray-500">...</span>
                          <kbd className="bg-gray-800 px-1.5 py-0.5 rounded text-gray-300">6</kbd>
                        </div>
                      </div>
                    </div>
                  </div>
                  
                  {/* Panel Controls */}
                  <div>
                    <h4 className="text-gray-200 font-medium mb-2">Panels</h4>
                    <div className="space-y-1 text-xs">
                      <div className="flex justify-between">
                        <span className="text-gray-400">Toggle analysis</span>
                        <kbd className="bg-gray-800 px-1.5 py-0.5 rounded text-gray-300">A</kbd>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-gray-400">This help</span>
                        <kbd className="bg-gray-800 px-1.5 py-0.5 rounded text-gray-300">?</kbd>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-gray-400">Close panels</span>
                        <kbd className="bg-gray-800 px-1.5 py-0.5 rounded text-gray-300">Esc</kbd>
                      </div>
                    </div>
                  </div>
                  
                  {/* System */}
                  <div>
                    <h4 className="text-gray-200 font-medium mb-2">System</h4>
                    <div className="space-y-1 text-xs">
                      <div className="flex justify-between">
                        <span className="text-gray-400">Settings</span>
                        <kbd className="bg-gray-800 px-1.5 py-0.5 rounded text-gray-300">Ctrl + ;</kbd>
                      </div>
                    </div>
                  </div>
                  
                  {/* Quick Reference */}
                  <div className="pt-2 border-t border-gray-700">
                    <p className="text-xs text-gray-500">
                      <strong className="text-gray-400">Quick themes:</strong> 
                      1=Default, 2=Rolodex, 3=Terminal, 4=Retro Digital, 5=Retro LCD, 6=Neon
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </>
      )}
      
      {/* Dev Toolbar - Bottom */}
      <div className="bg-gray-950/80 border-t border-gray-800/50">
        <div className="flex items-center justify-between px-4 py-1.5">
          {/* Left Side - Theme Selector */}
          <div className="flex items-center gap-3">
            <div className="flex items-center gap-2">
              <span className="text-xs text-gray-500 font-light">theme</span>
              <select
                value={selectedWatchFace}
                onChange={(e) => handleWatchFaceChange(e.target.value)}
                className="bg-gray-900/50 text-gray-300 text-xs font-light rounded px-2 py-1 border border-gray-700/50 hover:bg-gray-800/70 focus:outline-none focus:border-gray-600 cursor-pointer min-w-[100px]"
              >
                {WATCHFACES.map(wf => (
                  <option key={wf.id} value={wf.id}>
                    {wf.name}
                  </option>
                ))}
              </select>
            </div>
            
            {/* Analysis Toggle */}
            <button
              onClick={() => setShowAnalysisPanel(!showAnalysisPanel)}
              className={`flex items-center gap-1.5 px-2 py-1 text-xs font-light rounded transition-colors ${
                showAnalysisPanel 
                  ? 'bg-blue-600/20 text-blue-400 border border-blue-500/30' 
                  : 'text-gray-500 hover:text-gray-300 hover:bg-gray-800/50'
              }`}
            >
              <span className="text-[10px]">📋</span>
              <span>analysis</span>
            </button>
          </div>
          
          {/* Right Side - Version Labels */}
          <div className="flex items-center gap-2 text-xs text-gray-500 font-light">
            <span className="bg-blue-600/20 text-blue-400 px-1.5 py-0.5 rounded text-[10px] font-medium border border-blue-500/30">v1</span>
            <span className="text-gray-600">vs</span>
            <span className="bg-green-600/20 text-green-400 px-1.5 py-0.5 rounded text-[10px] font-medium border border-green-500/30">v2</span>
            <span className="ml-2 text-gray-600 text-[11px]">comparison</span>
          </div>
        </div>
      </div>
    </div>
  );
}