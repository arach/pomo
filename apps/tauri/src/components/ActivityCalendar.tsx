import React, { useMemo } from 'react';
import { useSessionStore } from '../stores/session-store';
import { Session } from '../stores/session-store';

interface DayData {
  date: Date;
  sessions: Session[];
  totalMinutes: number;
  intensity: 0 | 1 | 2 | 3 | 4; // 0 = no activity, 4 = high activity
}

export const ActivityCalendar: React.FC = () => {
  const sessions = useSessionStore(state => state.sessions);
  
  const calendarData = useMemo(() => {
    const today = new Date();
    const threeMonthsAgo = new Date(today);
    threeMonthsAgo.setMonth(today.getMonth() - 3);
    threeMonthsAgo.setDate(1); // Start from beginning of month
    
    // Generate all days in the range
    const days: DayData[] = [];
    const currentDate = new Date(threeMonthsAgo);
    
    while (currentDate <= today) {
      const dayStart = new Date(currentDate);
      dayStart.setHours(0, 0, 0, 0);
      const dayEnd = new Date(currentDate);
      dayEnd.setHours(23, 59, 59, 999);
      
      // Find sessions for this day
      const daySessions = sessions.filter(session => {
        const sessionDate = new Date(session.startTime);
        return sessionDate >= dayStart && sessionDate <= dayEnd;
      });
      
      // Calculate total focus time for the day
      const totalMinutes = daySessions
        .filter(s => s.sessionType === 'focus' && s.completed)
        .reduce((acc, s) => acc + ((s.actualDuration || s.duration) / 60), 0);
      
      // Calculate intensity (0-4 scale)
      let intensity: 0 | 1 | 2 | 3 | 4 = 0;
      if (totalMinutes > 0) intensity = 1;
      if (totalMinutes >= 30) intensity = 2;
      if (totalMinutes >= 60) intensity = 3;
      if (totalMinutes >= 120) intensity = 4;
      
      days.push({
        date: new Date(currentDate),
        sessions: daySessions,
        totalMinutes,
        intensity
      });
      
      currentDate.setDate(currentDate.getDate() + 1);
    }
    
    return days;
  }, [sessions]);
  
  // Group by weeks for display
  const weeks = useMemo(() => {
    const weeksArray: DayData[][] = [];
    let currentWeek: DayData[] = [];
    
    // Pad the beginning to start on Sunday
    const firstDay = calendarData[0]?.date;
    if (firstDay) {
      const dayOfWeek = firstDay.getDay();
      for (let i = 0; i < dayOfWeek; i++) {
        const paddingDate = new Date(firstDay);
        paddingDate.setDate(firstDay.getDate() - (dayOfWeek - i));
        currentWeek.push({
          date: paddingDate,
          sessions: [],
          totalMinutes: 0,
          intensity: 0
        });
      }
    }
    
    calendarData.forEach(day => {
      currentWeek.push(day);
      if (currentWeek.length === 7) {
        weeksArray.push(currentWeek);
        currentWeek = [];
      }
    });
    
    // Pad the end if needed
    if (currentWeek.length > 0) {
      while (currentWeek.length < 7) {
        const lastDate = currentWeek[currentWeek.length - 1].date;
        const nextDate = new Date(lastDate);
        nextDate.setDate(lastDate.getDate() + 1);
        currentWeek.push({
          date: nextDate,
          sessions: [],
          totalMinutes: 0,
          intensity: 0
        });
      }
      weeksArray.push(currentWeek);
    }
    
    return weeksArray;
  }, [calendarData]);
  
  const monthLabels = useMemo(() => {
    const labels: { month: string; colStart: number }[] = [];
    let currentMonth = -1;
    let colIndex = 0;
    
    weeks.forEach((week) => {
      week.forEach(() => {
        const date = week[0]?.date;
        if (date && date.getMonth() !== currentMonth) {
          currentMonth = date.getMonth();
          labels.push({
            month: date.toLocaleDateString('en-US', { month: 'short' }),
            colStart: colIndex
          });
        }
      });
      colIndex++;
    });
    
    return labels;
  }, [weeks]);
  
  const intensityColors = {
    0: 'bg-gray-100 dark:bg-gray-800',
    1: 'bg-red-200 dark:bg-red-900',
    2: 'bg-red-300 dark:bg-red-800',
    3: 'bg-red-400 dark:bg-red-700',
    4: 'bg-red-500 dark:bg-red-600'
  };
  
  const dayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
  
  return (
    <div className="p-2 bg-white dark:bg-gray-900 rounded-lg">
      <h3 className="text-xs font-mono font-semibold text-gray-700 dark:text-gray-300 mb-2 uppercase">
        Activity - Last 3 Months
      </h3>
      
      <div className="flex gap-1">
        {/* Day labels */}
        <div className="flex flex-col gap-0.5 text-xs font-mono text-gray-500 dark:text-gray-400 pr-1">
          {dayLabels.map((label, i) => (
            <div key={i} className="h-2.5 flex items-center text-[10px]">
              {i % 2 === 1 ? label : ''}
            </div>
          ))}
        </div>
        
        {/* Calendar grid */}
        <div className="relative">
          {/* Month labels */}
          <div className="flex gap-0.5 mb-0.5 text-[10px] font-mono text-gray-500 dark:text-gray-400">
            {monthLabels.map((label, i) => (
              <div
                key={i}
                className="absolute"
                style={{ left: `${label.colStart * 12}px` }}
              >
                {label.month}
              </div>
            ))}
          </div>
          
          {/* Activity grid */}
          <div className="flex gap-0.5 mt-5">
            {weeks.map((week, weekIndex) => (
              <div key={weekIndex} className="flex flex-col gap-0.5">
                {week.map((day, dayIndex) => {
                  const isToday = new Date().toDateString() === day.date.toDateString();
                  const isFuture = day.date > new Date();
                  
                  return (
                    <div
                      key={dayIndex}
                      className={`
                        w-2.5 h-2.5 rounded-sm transition-all cursor-pointer
                        ${isFuture ? 'opacity-30' : ''}
                        ${intensityColors[day.intensity]}
                        ${isToday ? 'ring-2 ring-red-500 ring-offset-1 dark:ring-offset-gray-900' : ''}
                        hover:scale-110
                      `}
                      title={`${day.date.toLocaleDateString()}: ${Math.round(day.totalMinutes)} minutes`}
                    />
                  );
                })}
              </div>
            ))}
          </div>
          
          {/* Legend */}
          <div className="flex items-center gap-1.5 mt-3 text-[10px] font-mono text-gray-500 dark:text-gray-400">
            <span>Less</span>
            <div className="flex gap-0.5">
              {[0, 1, 2, 3, 4].map(intensity => (
                <div
                  key={intensity}
                  className={`w-2.5 h-2.5 rounded-sm ${intensityColors[intensity as 0 | 1 | 2 | 3 | 4]}`}
                />
              ))}
            </div>
            <span>More</span>
          </div>
        </div>
      </div>
    </div>
  );
};