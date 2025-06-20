# 📊 Session Statistics Dashboard Specification

## Overview

The Session Statistics Dashboard provides users with meaningful insights into their focus patterns and productivity trends. It builds on the existing session naming functionality to create a compelling reason to name sessions while maintaining Pomo's elegant, focused design philosophy.

## Goals

### Primary Goals
- **Motivate session completion** through visible progress tracking
- **Provide actionable insights** about focus patterns and productivity
- **Encourage session naming** by showing named vs unnamed session benefits
- **Maintain Pomo's simplicity** - insights, not overwhelming analytics

### Secondary Goals
- **Export capability** for external analysis
- **Goal setting and tracking** for building focus habits
- **Beautiful data visualization** that matches Pomo's aesthetic

## Design Philosophy

### Stay True to Pomo
- **Clean, minimal interface** - No overwhelming charts or data
- **Focus on sessions, not minutes** - Quality over quantity metrics
- **Beautiful, not corporate** - Elegant visualizations that feel native
- **Actionable, not vanity** - Insights that help improve focus habits

### What We Won't Build
- ❌ Complex productivity analytics (that's Tempo's job)
- ❌ Time tracking with project categorization
- ❌ Team/collaboration features
- ❌ Goal-setting workflows with notifications

## User Stories

### US1: Session History View
```
As a user, I want to see my recent focus sessions
So that I can track my consistency and progress
```

**Acceptance Criteria:**
- [ ] Display last 30 days of sessions with names, duration, completion status
- [ ] Show session types with appropriate visual indicators
- [ ] Filter by date range, session type, or completion status
- [ ] Beautiful, scannable list format

### US2: Weekly Focus Patterns
```
As a user, I want to see my focus patterns by day of week
So that I can understand when I'm most productive
```

**Acceptance Criteria:**
- [ ] Heatmap or chart showing sessions by day of week
- [ ] Average session length by day
- [ ] Completion rate trends
- [ ] Best day of week insights

### US3: Session Completion Insights
```
As a user, I want to understand my focus session success rates
So that I can improve my concentration habits
```

**Acceptance Criteria:**
- [ ] Overall completion percentage
- [ ] Completion rates by session type
- [ ] Completion rates by session length
- [ ] Streak tracking (consecutive completed sessions)

### US4: Named vs Unnamed Sessions
```
As a user, I want to see how naming sessions affects my completion rate
So that I'm motivated to continue naming my sessions
```

**Acceptance Criteria:**
- [ ] Comparison of completion rates for named vs unnamed sessions
- [ ] Show most productive session names
- [ ] Encourage naming through visible benefits

## Technical Architecture

### Data Storage

#### Session Data Model
```typescript
interface SessionRecord {
  id: string;
  name: string | null;
  sessionType: SessionType;
  duration: number; // planned duration in seconds
  actualDuration: number; // how long it actually ran
  completed: boolean;
  startTime: Date;
  endTime: Date | null;
  interrupted: boolean; // true if user stopped early
  pauseCount: number; // how many times paused
  pauseDuration: number; // total pause time
}

interface SessionStats {
  totalSessions: number;
  completedSessions: number;
  completionRate: number;
  averageDuration: number;
  totalFocusTime: number;
  currentStreak: number;
  longestStreak: number;
  favoriteSessionTypes: { type: SessionType; count: number }[];
}
```

#### Storage Implementation
```rust
// src-tauri/src/session_storage.rs
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SessionDatabase {
    sessions: Vec<SessionRecord>,
    version: u32,
}

impl SessionDatabase {
    pub fn add_session(&mut self, session: SessionRecord) {
        self.sessions.push(session);
        self.save_to_disk();
    }
    
    pub fn get_sessions_in_range(&self, start: Date, end: Date) -> Vec<&SessionRecord> {
        // Implementation
    }
    
    pub fn calculate_stats(&self, date_range: Option<(Date, Date)>) -> SessionStats {
        // Implementation
    }
}
```

### Data Collection Integration

#### Update Timer Store
```typescript
// src/stores/timer-store.ts - additions
interface TimerState {
  // ... existing fields
  currentSessionStart: Date | null;
  pauseStartTime: Date | null;
  totalPauseTime: number;
}

// New methods
const useTimerStore = create<TimerState>((set, get) => ({
  // ... existing methods
  
  startSession: async () => {
    const state = get();
    await invoke('start_session_record', {
      name: state.sessionName,
      sessionType: state.sessionType,
      plannedDuration: state.duration,
      startTime: new Date().toISOString(),
    });
    
    set({ 
      currentSessionStart: new Date(),
      totalPauseTime: 0,
      isRunning: true 
    });
  },
  
  completeSession: async () => {
    const state = get();
    await invoke('complete_session_record', {
      endTime: new Date().toISOString(),
      completed: true,
      actualDuration: state.duration - state.remaining,
      pauseDuration: state.totalPauseTime,
    });
  },
  
  interruptSession: async () => {
    const state = get();
    await invoke('complete_session_record', {
      endTime: new Date().toISOString(), 
      completed: false,
      interrupted: true,
      actualDuration: state.duration - state.remaining,
      pauseDuration: state.totalPauseTime,
    });
  },
}));
```

#### Rust Commands
```rust
// src-tauri/src/lib.rs - additions
#[tauri::command]
async fn start_session_record(
    name: Option<String>,
    session_type: String,
    planned_duration: u32,
    start_time: String,
    db: State<'_, SessionDatabase>,
) -> Result<String, String> {
    let session = SessionRecord {
        id: uuid::Uuid::new_v4().to_string(),
        name,
        session_type: session_type.parse().unwrap(),
        duration: planned_duration,
        start_time: start_time.parse().unwrap(),
        // ... other fields
    };
    
    db.lock().await.add_session(session.clone());
    Ok(session.id)
}

#[tauri::command]
async fn get_session_stats(
    start_date: Option<String>,
    end_date: Option<String>,
    db: State<'_, SessionDatabase>,
) -> Result<SessionStats, String> {
    // Implementation
}
```

## User Interface Design

### Statistics Window

#### Main Dashboard Layout
```tsx
// src/pages/statistics.tsx
function StatisticsWindow() {
  const [dateRange, setDateRange] = useState('last30days');
  const [stats, setStats] = useState<SessionStats | null>(null);
  
  return (
    <WindowWrapper>
      <CustomTitleBar title="Focus Statistics" />
      
      <div className="flex flex-col h-full bg-background pt-7">
        <div className="px-6 py-4 border-b border-border/30">
          <div className="flex items-center justify-between">
            <h2 className="text-xl font-brand">Your Focus Journey</h2>
            <DateRangeSelector 
              value={dateRange} 
              onChange={setDateRange} 
            />
          </div>
        </div>
        
        <div className="flex-1 p-6 overflow-y-auto">
          <div className="max-w-4xl mx-auto space-y-6">
            <StatsOverview stats={stats} />
            <FocusPatterns stats={stats} />
            <SessionHistory dateRange={dateRange} />
            <SessionInsights stats={stats} />
          </div>
        </div>
      </div>
    </WindowWrapper>
  );
}
```

#### Stats Overview Component
```tsx
function StatsOverview({ stats }: { stats: SessionStats }) {
  return (
    <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
      <StatCard 
        title="Completion Rate"
        value={`${Math.round(stats.completionRate * 100)}%`}
        subtitle={`${stats.completedSessions}/${stats.totalSessions} sessions`}
        icon="🎯"
        trend={calculateTrend(stats.completionRate)}
      />
      
      <StatCard
        title="Current Streak" 
        value={stats.currentStreak}
        subtitle="completed sessions"
        icon="🔥"
        highlight={stats.currentStreak >= 5}
      />
      
      <StatCard
        title="Total Focus Time"
        value={formatDuration(stats.totalFocusTime)}
        subtitle="this period"
        icon="⏱️"
      />
      
      <StatCard
        title="Average Session"
        value={formatDuration(stats.averageDuration)}
        subtitle="typical length"
        icon="📊"
      />
    </div>
  );
}
```

#### Focus Patterns Visualization
```tsx
function FocusPatterns({ stats }: { stats: SessionStats }) {
  return (
    <div className="bg-muted/20 rounded-lg p-6">
      <h3 className="text-lg font-medium mb-4">Weekly Focus Pattern</h3>
      
      <WeeklyHeatmap data={stats.weeklyPattern} />
      
      <div className="mt-4 text-sm text-muted-foreground">
        <p>Your most productive day: <strong>{stats.bestDayOfWeek}</strong></p>
        <p>Average sessions per day: <strong>{stats.averageSessionsPerDay}</strong></p>
      </div>
    </div>
  );
}
```

#### Session History Component
```tsx
function SessionHistory({ dateRange }: { dateRange: string }) {
  const [sessions, setSessions] = useState<SessionRecord[]>([]);
  
  return (
    <div className="bg-muted/20 rounded-lg p-6">
      <div className="flex items-center justify-between mb-4">
        <h3 className="text-lg font-medium">Recent Sessions</h3>
        <Button 
          variant="ghost" 
          size="sm"
          onClick={() => exportSessions(sessions)}
        >
          Export
        </Button>
      </div>
      
      <div className="space-y-2 max-h-96 overflow-y-auto">
        {sessions.map(session => (
          <SessionItem key={session.id} session={session} />
        ))}
      </div>
    </div>
  );
}

function SessionItem({ session }: { session: SessionRecord }) {
  return (
    <div className="flex items-center justify-between py-2 px-3 rounded bg-background/50 hover:bg-background/70 transition-colors">
      <div className="flex items-center gap-3">
        <SessionTypeIcon type={session.sessionType} />
        <div>
          <p className="font-medium">
            {session.name || 'Unnamed Session'}
          </p>
          <p className="text-sm text-muted-foreground">
            {formatDate(session.startTime)} • {formatDuration(session.duration)}
          </p>
        </div>
      </div>
      
      <div className="flex items-center gap-2">
        {session.completed ? (
          <Badge variant="success">Completed</Badge>
        ) : (
          <Badge variant="secondary">Incomplete</Badge>
        )}
        <span className="text-sm text-muted-foreground">
          {Math.round((session.actualDuration / session.duration) * 100)}%
        </span>
      </div>
    </div>
  );
}
```

### Menu Integration

#### Add Statistics to Menu Bar
```rust
// In update_tray_menu function - add menu item
let stats_item = MenuItem::with_id(app_handle, "stats", "📊 Statistics", true, None::<&str>).map_err(|e| e.to_string())?;

// In tray event handler
"stats" => {
    open_statistics_window(app_handle.clone()).await.ok();
}
```

#### Statistics Window Command
```rust
#[tauri::command]
async fn open_statistics_window(app_handle: tauri::AppHandle) -> Result<(), String> {
    if let Some(window) = app_handle.get_webview_window("statistics") {
        window.show().ok();
        window.set_focus().ok();
    } else {
        let stats_window = tauri::WebviewWindowBuilder::new(
            &app_handle,
            "statistics", 
            tauri::WebviewUrl::App("/statistics".into()),
        )
        .title("Pomo Statistics")
        .inner_size(800.0, 600.0)
        .resizable(true)
        .transparent(true)
        .decorations(false)
        .always_on_top(false) // Statistics can be behind main window
        .build()
        .map_err(|e| e.to_string())?;
    }
    Ok(())
}
```

## Implementation Timeline

### Week 1: Data Foundation
- [ ] Design and implement SessionRecord data structure
- [ ] Create session storage system in Rust
- [ ] Add session tracking to timer store
- [ ] Test data collection during timer sessions

### Week 2: Basic Statistics
- [ ] Implement session stats calculation
- [ ] Create statistics window with basic overview
- [ ] Add stats overview cards (completion rate, streak, etc.)
- [ ] Integrate with menu bar

### Week 3: Visualizations & History
- [ ] Build session history list with filtering
- [ ] Create weekly focus pattern visualization
- [ ] Add named vs unnamed session insights
- [ ] Polish UI and interactions

### Week 4: Export & Refinement
- [ ] Add data export functionality
- [ ] Performance optimization for large datasets
- [ ] Edge case handling and error states
- [ ] User testing and refinements

## Success Metrics

### Engagement
- **Statistics Window Usage:** % of users who open statistics window
- **Session Naming Increase:** % increase in named sessions after viewing stats
- **Session Completion Improvement:** % improvement in completion rates

### Data Quality
- **Data Accuracy:** Verify session timing and completion tracking
- **Performance:** Statistics calculation time < 100ms for 1000 sessions
- **Storage Efficiency:** Database size growth rate

## Future Enhancements

### Advanced Insights
- **Focus quality scoring** based on pause frequency
- **Optimal session length** recommendations
- **Productive time of day** analysis
- **Session name effectiveness** (which names lead to better completion)

### Goal Setting
- **Weekly focus goals** (number of sessions, total time)
- **Streak challenges** (maintain 10-day completion streak)
- **Progress celebrations** (achievements and milestones)

### Export & Integration
- **CSV/JSON export** for external analysis
- **Calendar integration** to show focus blocks
- **Health app integration** (mindfulness minutes)

---

This dashboard will make session naming incredibly valuable while keeping Pomo focused on its core timer functionality. The insights will motivate users to maintain their focus habits without overwhelming them with complex analytics.