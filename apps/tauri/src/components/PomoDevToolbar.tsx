import React from 'react';
import { DevToolbar, DevToolbarSection, DevToolbarButton, DevToolbarInfo } from '@arach/devbar';
import { Timer, Activity, Database, Settings, RefreshCw, Trash2 } from 'lucide-react';
import { useTimerStore } from '../stores/timer-store';
import { useSessionStore } from '../stores/session-store';
import { useSettingsStore } from '../stores/settings-store';

export const PomoDevToolbar: React.FC = () => {
  const timerStore = useTimerStore();
  const sessionStore = useSessionStore();
  const settingsStore = useSettingsStore();
  const sessions = useSessionStore(state => state.sessions);
  const stats = useSessionStore(state => state.getSessionStats());
  
  const addMockSessions = () => {
    const today = new Date();
    for (let i = 0; i < 90; i++) {
      const date = new Date(today);
      date.setDate(today.getDate() - i);
      
      const sessionsCount = Math.floor(Math.random() * 9);
      
      for (let j = 0; j < sessionsCount; j++) {
        const startTime = new Date(date);
        startTime.setHours(8 + Math.floor(Math.random() * 12), Math.floor(Math.random() * 60));
        
        sessionStore.addSession({
          id: `mock-${i}-${j}`,
          startTime,
          endTime: new Date(startTime.getTime() + 25 * 60 * 1000),
          duration: 25 * 60,
          actualDuration: 25 * 60,
          sessionType: 'focus',
          completed: true,
          pauseCount: 0,
          pauseDuration: 0,
          name: undefined
        });
      }
    }
  };
  
  const tabs = [
    {
      id: 'timer',
      label: 'Timer',
      icon: Timer,
      content: (
        <DevToolbarSection>
          <div className="grid grid-cols-2 gap-x-3 gap-y-1">
            <DevToolbarInfo label="Running" value={timerStore.isRunning ? 'Yes' : 'No'} />
            <DevToolbarInfo label="Paused" value={timerStore.isPaused ? 'Yes' : 'No'} />
            <DevToolbarInfo 
              theme="dark"
              label="Time Left" 
              value={`${Math.floor(timerStore.remaining / 60)}:${(timerStore.remaining % 60).toString().padStart(2, '0')}`} 
            />
            <DevToolbarInfo label="Duration" value={`${Math.floor(timerStore.duration / 60)} min`} />
            <DevToolbarInfo label="Type" value={timerStore.sessionType} />
            <DevToolbarInfo label="Pauses" value={timerStore.pauseCount} />
          </div>
          {timerStore.sessionName && (
            <DevToolbarInfo label="Name" value={timerStore.sessionName} />
          )}
          
          <div className="pt-1 grid grid-cols-4 gap-0.5">
            <DevToolbarButton variant="success" onClick={() => timerStore.start()}>
              Start
            </DevToolbarButton>
            <DevToolbarButton variant="warning" onClick={() => timerStore.pause()}>
              Pause
            </DevToolbarButton>
            <DevToolbarButton variant="danger" onClick={() => timerStore.stop()}>
              Stop
            </DevToolbarButton>
            <DevToolbarButton onClick={() => timerStore.reset()}>
              Reset
            </DevToolbarButton>
          </div>
        </DevToolbarSection>
      )
    },
    {
      id: 'activity',
      label: 'Activity',
      icon: Activity,
      content: (
        <DevToolbarSection title="Activity Stats">
          <div className="grid grid-cols-2 gap-x-3 gap-y-1">
            <DevToolbarInfo label="Sessions" value={stats.totalSessions} />
            <DevToolbarInfo label="Completed" value={stats.completedSessions} />
            <DevToolbarInfo label="Total" value={`${Math.round(stats.totalFocusTime / 60)}m`} />
            <DevToolbarInfo label="Avg" value={`${Math.round(stats.averageSessionDuration / 60)}m`} />
          </div>
          
          <div className="flex gap-1 mt-2">
            <DevToolbarButton onClick={addMockSessions} className="flex items-center gap-0.5">
              <RefreshCw className="w-2.5 h-2.5" />
              Mock Data
            </DevToolbarButton>
            <DevToolbarButton 
              variant="danger" 
              onClick={() => window.location.reload()}
              className="flex items-center gap-0.5"
            >
              <Trash2 className="w-2.5 h-2.5" />
              Clear
            </DevToolbarButton>
          </div>
        </DevToolbarSection>
      )
    },
    {
      id: 'sessions',
      label: 'Sessions',
      icon: Database,
      content: () => {
        return (
          <DevToolbarSection title={`Recent Sessions (${sessions.length} total)`}>
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
          </DevToolbarSection>
        );
      }
    },
    {
      id: 'settings',
      label: 'Settings',
      icon: Settings,
      content: (
        <DevToolbarSection>
          <div className="grid grid-cols-2 gap-x-3 gap-y-1">
            <DevToolbarInfo label="Duration" value={`${Math.floor(settingsStore.defaultDuration / 60)}m`} />
            <DevToolbarInfo label="Theme" value={settingsStore.theme} />
            <DevToolbarInfo label="Sound" value={settingsStore.soundEnabled ? 'On' : 'Off'} />
            <DevToolbarInfo label="Volume" value={`${Math.round(settingsStore.volume * 100)}%`} />
            <DevToolbarInfo label="On Top" value={settingsStore.alwaysOnTop ? 'Yes' : 'No'} />
            <DevToolbarInfo label="Opacity" value={`${Math.round(settingsStore.opacity * 100)}%`} />
            <DevToolbarInfo label="Face" value={settingsStore.watchFace} />
            <DevToolbarInfo label="Alert" value={settingsStore.notificationSound} />
          </div>
          
          <div className="pt-2">
            <DevToolbarButton
              variant="danger"
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
              className="w-full"
            >
              Reset Defaults
            </DevToolbarButton>
          </div>
        </DevToolbarSection>
      )
    }
  ];
  
  return <DevToolbar tabs={tabs} hideInProduction={true} theme="dark" />;
};