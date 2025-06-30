import { useState, useEffect } from 'react';
import { X, Coffee, PlayCircle, BarChart3, CheckCircle2 } from 'lucide-react';
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
  const [note, setNote] = useState('');
  const [showCelebration, setShowCelebration] = useState(true);
  const { start, setDuration, setSessionType } = useTimerStore();
  const sessions = useSessionStore((state) => state.sessions);
  
  // Get today's sessions
  const todaysSessions = sessions.filter(s => {
    const sessionDate = new Date(s.startTime);
    const today = new Date();
    return sessionDate.toDateString() === today.toDateString();
  });
  
  const completedToday = todaysSessions.filter(s => s.completed).length;
  const focusTimeToday = todaysSessions
    .filter(s => s.completed && s.sessionType === 'focus')
    .reduce((acc, s) => acc + s.duration, 0);

  useEffect(() => {
    if (isOpen) {
      setShowCelebration(true);
      // Reset celebration after animation
      const timer = setTimeout(() => setShowCelebration(false), 2000);
      return () => clearTimeout(timer);
    }
  }, [isOpen]);

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
      <div className="bg-gradient-to-b from-gray-800 to-gray-900 rounded-xl shadow-2xl p-4 w-full max-w-[280px] relative overflow-hidden border border-gray-700/50">
        {/* Background decoration */}
        <div className="absolute inset-0 bg-gradient-to-br from-green-500/10 via-transparent to-blue-500/10 pointer-events-none" />
        
        {/* Celebration animation */}
        {showCelebration && (
          <div className="absolute inset-0 pointer-events-none">
            <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2">
              <CheckCircle2 className="w-16 h-16 text-green-400 animate-ping" />
            </div>
          </div>
        )}

        {/* Close button */}
        <button
          onClick={onClose}
          className="absolute top-2 right-2 text-gray-500 hover:text-gray-300 transition-all duration-200 z-20"
        >
          <X className="w-4 h-4" />
        </button>

        {/* Header - Compact */}
        <div className="text-center mb-3 relative z-10">
          <div className="inline-flex items-center justify-center w-12 h-12 bg-gradient-to-br from-green-400 to-green-500 rounded-full mb-3 shadow-lg shadow-green-500/30">
            <CheckCircle2 className="w-6 h-6 text-white" />
          </div>
          <h2 className="text-xl font-bold text-white mb-1">
            Complete! 🎉
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

        {/* Quick note */}
        <div className="mb-4 relative z-10">
          <label className="block text-xs font-medium text-gray-400 mb-1.5">
            Quick note (optional)
          </label>
          <input
            type="text"
            value={note}
            onChange={(e) => setNote(e.target.value)}
            placeholder="What did you accomplish?"
            className="w-full px-3 py-2 text-sm bg-gray-800/50 border border-gray-700/50 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:border-green-500/50 focus:ring-1 focus:ring-green-500/20 transition-all duration-200"
            autoFocus
          />
        </div>

        {/* Action buttons - Compact */}
        <div className="grid grid-cols-2 gap-2 mb-4 relative z-10">
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
        <div className="border-t border-gray-700/50 pt-3 relative z-10">
          <div className="flex items-center justify-between text-xs">
            <div className="flex items-center gap-4">
              <div className="flex items-center gap-1.5">
                <span className="text-gray-400">Today:</span>
                <div className="flex items-center gap-1">
                  {[...Array(5)].map((_, i) => (
                    <div
                      key={i}
                      className={`w-2 h-2 rounded-full transition-all duration-300 ${
                        i < completedToday 
                          ? 'bg-green-400 shadow-sm shadow-green-400/50' 
                          : 'bg-gray-700'
                      }`}
                    />
                  ))}
                </div>
                <span className="text-gray-300 font-medium">{completedToday}</span>
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