import React, { useState } from 'react';
import { Bug, X, Activity, Timer, Settings, Database, RefreshCw, Trash2 } from 'lucide-react';
import { useTimerStore } from '../stores/timer-store';
import { useSessionStore } from '../stores/session-store';
import { useSettingsStore } from '../stores/settings-store';
import { ActivityCalendar } from './ActivityCalendar';

type DevTab = 'activity' | 'timer' | 'sessions' | 'settings';

export const DevToolbar: React.FC = () => {
  const [isCollapsed, setIsCollapsed] = useState(true);
  const [activeTab, setActiveTab] = useState<DevTab>('activity');
  
  // Store states
  const timerStore = useTimerStore();
  const sessionStore = useSessionStore();
  const settingsStore = useSettingsStore();
  const sessions = useSessionStore(state => state.sessions);
  const stats = useSessionStore(state => state.getSessionStats());
  
  // Dev actions
  const addMockSessions = () => {
    const today = new Date();
    for (let i = 0; i < 90; i++) {
      const date = new Date(today);
      date.setDate(today.getDate() - i);
      
      // Random number of sessions per day (0-8)
      const sessionsCount = Math.floor(Math.random() * 9);
      
      for (let j = 0; j < sessionsCount; j++) {
        const startTime = new Date(date);
        startTime.setHours(8 + Math.floor(Math.random() * 12), Math.floor(Math.random() * 60));
        
        const session = {
          id: `mock-${i}-${j}`,
          startTime,
          endTime: new Date(startTime.getTime() + 25 * 60 * 1000),
          duration: 25 * 60,
          actualDuration: 25 * 60,
          sessionType: 'focus' as const,
          completed: true,
          pauseCount: 0,
          pauseDuration: 0
        };
        
        sessionStore.addSession(session);
      }
    }
  };
  
  const clearAllSessions = () => {
    if (confirm('Clear all session data?')) {
      // This would need to be implemented in the store
      window.location.reload(); // Temporary solution
    }
  };
  
  if (process.env.NODE_ENV !== 'development') {
    return null;
  }
  
  return (
    <>
      {/* Bug button - always visible in dev mode */}
      <button
        onClick={() => setIsCollapsed(!isCollapsed)}
        className="fixed bottom-3 right-3 w-8 h-8 rounded-full
                   bg-gray-900 dark:bg-black
                   backdrop-blur-sm
                   border border-gray-700 dark:border-gray-800
                   shadow-lg shadow-black/50
                   flex items-center justify-center
                   text-white hover:text-white
                   hover:bg-gray-800
                   transition-all duration-300
                   hover:scale-110 active:scale-95
                   z-[9999]"
        title={isCollapsed ? "Show dev toolbar" : "Hide dev toolbar"}
      >
        <Bug className={`w-4 h-4 transition-transform duration-300 ${
          isCollapsed ? '' : 'rotate-180'
        }`} />
      </button>
      
      {/* Dev toolbar panel */}
      {!isCollapsed && (
        <div className="fixed bottom-3 right-3 w-[280px] max-h-[240px] rounded
                        bg-gray-900/95 dark:bg-black/95
                        backdrop-blur-sm
                        border border-gray-700/50 dark:border-gray-800
                        shadow-2xl shadow-black/50
                        z-[9998]
                        overflow-hidden
                        flex flex-col">
          {/* Header */}
          <div className="flex items-center justify-between px-2 py-1 border-b border-gray-700/50">
            <div className="flex items-center gap-1">
              <Bug className="w-3 h-3 text-gray-400" />
              <h3 className="font-medium text-white text-[10px]">Dev</h3>
            </div>
            <button
              onClick={() => setIsCollapsed(true)}
              className="text-gray-400 hover:text-white transition-colors"
            >
              <X className="w-3 h-3" />
            </button>
          </div>
          
          {/* Tabs */}
          <div className="flex border-b border-gray-700/50">
            {[
              { id: 'activity' as const, label: 'Activity', icon: Activity },
              { id: 'timer' as const, label: 'Timer', icon: Timer },
              { id: 'sessions' as const, label: 'Sessions', icon: Database },
              { id: 'settings' as const, label: 'Settings', icon: Settings }
            ].map(({ id, label, icon: Icon }) => (
              <button
                key={id}
                onClick={() => setActiveTab(id)}
                className={`flex-1 px-1 py-0.5 text-[10px] font-medium transition-colors
                  ${activeTab === id
                    ? 'bg-gray-800 text-white border-b-2 border-red-500'
                    : 'text-gray-400 hover:text-white hover:bg-gray-800/50'
                  }`}
              >
                <Icon className="w-2.5 h-2.5" title={label} />
              </button>
            ))}
          </div>
          
          {/* Content */}
          <div className="flex-1 overflow-auto p-2">
            {activeTab === 'activity' && (
              <div className="space-y-2">
                <ActivityCalendar />
                
                <div className="flex gap-1">
                  <button
                    onClick={addMockSessions}
                    className="px-1.5 py-0.5 bg-gray-800 hover:bg-gray-700 text-white text-[10px] rounded
                             transition-colors flex items-center gap-0.5"
                  >
                    <RefreshCw className="w-2.5 h-2.5" />
                    Mock Data
                  </button>
                  <button
                    onClick={clearAllSessions}
                    className="px-1.5 py-0.5 bg-red-900 hover:bg-red-800 text-white text-[10px] rounded
                             transition-colors flex items-center gap-0.5"
                  >
                    <Trash2 className="w-2.5 h-2.5" />
                    Clear
                  </button>
                </div>
                
                <div className="text-[10px] font-mono text-gray-400 space-y-0.5">
                  <div>Total Sessions: {stats.totalSessions}</div>
                  <div>Completed: {stats.completedSessions}</div>
                  <div>Total Focus: {Math.round(stats.totalFocusTime / 60)} min</div>
                  <div>Avg Duration: {Math.round(stats.averageSessionDuration / 60)} min</div>
                </div>
              </div>
            )}
            
            {activeTab === 'timer' && (
              <div className="space-y-1 text-[10px] font-mono text-gray-300">
                <div>Running: {timerStore.isRunning ? 'Yes' : 'No'}</div>
                <div>Paused: {timerStore.isPaused ? 'Yes' : 'No'}</div>
                <div>Time Left: {Math.floor(timerStore.remaining / 60)}:{(timerStore.remaining % 60).toString().padStart(2, '0')}</div>
                <div>Duration: {Math.floor(timerStore.duration / 60)} min</div>
                <div>Session Type: {timerStore.sessionType}</div>
                <div>Session Name: {timerStore.sessionName || 'None'}</div>
                <div>Pause Count: {timerStore.pauseCount}</div>
                
                <div className="pt-2 grid grid-cols-4 gap-0.5">
                  <button
                    onClick={() => timerStore.start()}
                    className="px-1 py-0.5 bg-green-800 hover:bg-green-700 text-white text-[9px] rounded
                             transition-colors"
                  >
                    Start
                  </button>
                  <button
                    onClick={() => timerStore.pause()}
                    className="px-1 py-0.5 bg-yellow-800 hover:bg-yellow-700 text-white text-[9px] rounded
                             transition-colors"
                  >
                    Pause
                  </button>
                  <button
                    onClick={() => timerStore.stop()}
                    className="px-1 py-0.5 bg-red-800 hover:bg-red-700 text-white text-[9px] rounded
                             transition-colors"
                  >
                    Stop
                  </button>
                  <button
                    onClick={() => timerStore.reset()}
                    className="px-1 py-0.5 bg-gray-800 hover:bg-gray-700 text-white text-[9px] rounded
                             transition-colors"
                  >
                    Reset
                  </button>
                </div>
              </div>
            )}
            
            {activeTab === 'sessions' && (
              <div className="space-y-1">
                <div className="text-[10px] font-mono text-gray-400">
                  Recent Sessions ({sessions.length} total)
                </div>
                <div className="space-y-0.5 max-h-32 overflow-auto">
                  {sessions.slice(-10).reverse().map(session => (
                    <div
                      key={session.id}
                      className="text-[10px] font-mono text-gray-300 p-1 bg-gray-800 rounded"
                    >
                      <div className="flex justify-between">
                        <span>{new Date(session.startTime).toLocaleString()}</span>
                        <span className={session.completed ? 'text-green-400' : 'text-yellow-400'}>
                          {session.completed ? '✓' : '○'}
                        </span>
                      </div>
                      <div className="text-gray-500">
                        {session.sessionType} - {Math.round(session.duration / 60)} min
                        {session.name && ` - ${session.name}`}
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            )}
            
            {activeTab === 'settings' && (
              <div className="space-y-1 text-[10px] font-mono text-gray-300">
                <div>Default Duration: {Math.floor(settingsStore.defaultDuration / 60)} min</div>
                <div>Theme: {settingsStore.theme}</div>
                <div>Sound: {settingsStore.soundEnabled ? 'On' : 'Off'}</div>
                <div>Volume: {Math.round(settingsStore.volume * 100)}%</div>
                <div>Always on Top: {settingsStore.alwaysOnTop ? 'Yes' : 'No'}</div>
                <div>Opacity: {Math.round(settingsStore.opacity * 100)}%</div>
                <div>Watch Face: {settingsStore.watchFace}</div>
                <div>Notification Sound: {settingsStore.notificationSound}</div>
                
                <div className="pt-2">
                  <button
                    onClick={async () => {
                      await settingsStore.updateSettings({
                        soundEnabled: true,
                        volume: 0.5,
                        opacity: 0.95,
                        alwaysOnTop: true,
                        defaultDuration: 25 * 60,
                        theme: 'dark',
                        notificationSound: 'zen',
                        watchFace: 'default'
                      });
                      alert('Settings reset to defaults');
                    }}
                    className="px-1.5 py-0.5 bg-red-900 hover:bg-red-800 text-white text-[10px] rounded
                             transition-colors w-full"
                  >
                    Reset Defaults
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>
      )}
    </>
  );
};