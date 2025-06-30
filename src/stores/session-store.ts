import { create } from 'zustand';
import { SessionType } from './timer-store';

export interface Session {
  id: string;
  startTime: Date;
  endTime?: Date;
  duration: number;
  actualDuration?: number;
  sessionType: SessionType;
  name?: string;
  completed: boolean;
  pauseCount: number;
  pauseDuration: number;
}

interface SessionStore {
  sessions: Session[];
  addSession: (session: Session) => void;
  updateSession: (id: string, updates: Partial<Session>) => void;
  getTodaysSessions: () => Session[];
  getSessionStats: () => {
    totalSessions: number;
    completedSessions: number;
    totalFocusTime: number;
    averageSessionDuration: number;
  };
}

export const useSessionStore = create<SessionStore>((set, get) => ({
  sessions: [],
  
  addSession: (session) => {
    set((state) => ({
      sessions: [...state.sessions, session]
    }));
  },
  
  updateSession: (id, updates) => {
    set((state) => ({
      sessions: state.sessions.map(session =>
        session.id === id ? { ...session, ...updates } : session
      )
    }));
  },
  
  getTodaysSessions: () => {
    const sessions = get().sessions;
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    
    return sessions.filter(session => {
      const sessionDate = new Date(session.startTime);
      sessionDate.setHours(0, 0, 0, 0);
      return sessionDate.getTime() === today.getTime();
    });
  },
  
  getSessionStats: () => {
    const sessions = get().sessions;
    const completedSessions = sessions.filter(s => s.completed);
    const focusSessions = completedSessions.filter(s => s.sessionType === 'focus');
    
    const totalFocusTime = focusSessions.reduce((acc, s) => acc + (s.actualDuration || s.duration), 0);
    const averageSessionDuration = completedSessions.length > 0
      ? totalFocusTime / completedSessions.length
      : 0;
    
    return {
      totalSessions: sessions.length,
      completedSessions: completedSessions.length,
      totalFocusTime,
      averageSessionDuration
    };
  }
}));