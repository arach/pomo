import { useEffect } from 'react';
import { X, Coffee, PlayCircle, BarChart3 } from 'lucide-react';
import { useTimerStore } from '../stores/timer-store';
import { useSessionStore } from '../stores/session-store';
import { formatDuration } from '../utils/format';
import { SessionType } from '../stores/timer-store';

interface SessionCompleteModalProps {
  isOpen: boolean;
  onClose: () => void;
  session: {
    duration: number;
    sessionType: SessionType;
    name?: string;
    pauseCount: number;
  };
}

export function SessionCompleteModal({ isOpen, onClose, session }: SessionCompleteModalProps) {
  const { start, setDuration, setSessionType } = useTimerStore();
  const { getTodaysSessions } = useSessionStore();
  
  // Get today's sessions using the store method
  const todaysSessions = getTodaysSessions();
  const completedToday = todaysSessions.filter(s => s.completed).length;
  const focusTimeToday = todaysSessions
    .filter(s => s.completed && s.sessionType === 'focus')
    .reduce((acc, s) => acc + s.duration, 0);

  useEffect(() => {
    if (isOpen) {
      // Auto-dismiss after 120 seconds
      const timer = setTimeout(() => onClose(), 120000);
      return () => clearTimeout(timer);
    }
  }, [isOpen, onClose]);

  const handleStartBreak = async () => {
    const breakDuration = session.sessionType === 'focus' ? 5 * 60 : 25 * 60;
    const newSessionType = session.sessionType === 'focus' ? 'break' : 'focus';
    setSessionType(newSessionType);
    await setDuration(breakDuration);
    await start();
    onClose();
  };

  const handleContinue = async () => {
    await setDuration(session.duration);
    await start();
    onClose();
  };

  const handleViewStats = () => {
    // TODO: Implement stats view
    console.log('View stats');
    onClose();
  };

  if (!isOpen) return null;

  const isBreak = session.sessionType === 'break';

  return (
    <div className="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center z-50 animate-fade-in p-4">
      <div className="bg-gradient-to-b from-gray-800 to-gray-900 rounded-xl shadow-2xl p-3 w-full max-w-[260px] relative overflow-hidden border border-gray-700/50">
        {/* Background decoration */}
        <div className="absolute inset-0 bg-gradient-to-br from-green-500/10 via-transparent to-blue-500/10 pointer-events-none" />

        {/* Close button */}
        <button
          onClick={onClose}
          className="absolute top-2 right-2 text-gray-500 hover:text-gray-300 transition-all duration-200 z-20"
        >
          <X className="w-4 h-4" />
        </button>

        {/* Header - Compact */}
        <div className="text-center mb-3 relative z-10">
          <h2 className="text-lg font-semibold text-white mb-1">
            Session Done
          </h2>
          <p className="text-sm text-gray-300">
            {formatDuration(session.duration)}
            {session.name && ` · ${session.name}`}
          </p>
          {session.pauseCount > 0 && (
            <p className="text-xs text-gray-400 mt-1">
              {session.pauseCount} pause{session.pauseCount > 1 ? 's' : ''}
            </p>
          )}
        </div>


        {/* Action buttons - Compact */}
        <div className="grid grid-cols-2 gap-2 mb-3 relative z-10">
          <button
            onClick={handleStartBreak}
            className="group flex items-center justify-center gap-1.5 px-3 py-2 bg-gradient-to-r from-blue-500 to-blue-600 hover:from-blue-600 hover:to-blue-700 text-white text-sm font-medium rounded-lg transition-all duration-200 shadow-lg shadow-blue-500/25"
          >
            <Coffee className="w-4 h-4" />
            <span className="truncate">{isBreak ? 'Focus' : 'Break'}</span>
          </button>
          <button
            onClick={handleContinue}
            className="group flex items-center justify-center gap-1.5 px-3 py-2 bg-gray-700/50 hover:bg-gray-600/50 text-white text-sm font-medium rounded-lg transition-all duration-200 border border-gray-600/50"
          >
            <PlayCircle className="w-4 h-4" />
            Continue
          </button>
        </div>

        {/* Today's stats - Compact */}
        <div className="border-t border-gray-700/50 pt-2 relative z-10">
          <div className="flex items-center justify-between text-xs">
            <div className="flex items-center gap-3">
              <div className="flex items-center gap-1.5">
                <span className="text-gray-400">Today:</span>
                <div className="flex items-center gap-0.5">
                  {[...Array(completedToday)].map((_, i) => (
                    <div
                      key={i}
                      className="w-2 h-2 rounded-full bg-green-400 shadow-sm shadow-green-400/50 transition-all duration-300"
                    />
                  ))}
                </div>
                <span className="text-gray-300 font-medium ml-1">{completedToday}</span>
              </div>
              <div className="text-gray-400">
                {formatDuration(focusTimeToday)}
              </div>
            </div>
            <button
              onClick={handleViewStats}
              className="flex items-center gap-1 px-2 py-0.5 text-gray-400 hover:text-white hover:bg-gray-700/30 rounded transition-all duration-200"
            >
              <BarChart3 className="w-3 h-3" />
              <span>Stats</span>
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}