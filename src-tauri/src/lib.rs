#![allow(deprecated)] // Allow deprecated warnings for cocoa::base::id until migration to objc2

use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tauri::{Emitter, Manager, State};
use tauri_plugin_global_shortcut::{GlobalShortcutExt, Code, Modifiers, Shortcut, ShortcutState};
use tauri::tray::TrayIconBuilder;
use tauri::menu::{Menu, MenuItem, Submenu, PredefinedMenuItem};
use tokio::sync::Mutex;
use std::time::Duration;
use std::fs;
use chrono::{DateTime, Utc};
use tauri::async_runtime::JoinHandle;
use image::{ImageBuffer, Rgba, RgbaImage};
use rusttype::{Font, Scale};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TimerState {
    pub duration: u32, // Duration in seconds
    pub remaining: u32, // Remaining time in seconds
    pub is_running: bool,
    pub is_paused: bool,
    pub session_name: Option<String>, // Optional session name
    pub current_session_id: Option<String>, // Track current session for statistics
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SessionRecord {
    pub id: String,
    pub name: Option<String>,
    pub session_type: String, // SessionType as string for serialization
    pub duration: u32, // Planned duration in seconds
    pub actual_duration: u32, // How long it actually ran
    pub completed: bool,
    pub start_time: DateTime<Utc>,
    pub end_time: Option<DateTime<Utc>>,
    pub interrupted: bool, // True if user stopped early
    pub pause_count: u32, // How many times paused
    pub pause_duration: u32, // Total pause time in seconds
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SessionStats {
    pub total_sessions: u32,
    pub completed_sessions: u32,
    pub completion_rate: f64,
    pub average_duration: f64,
    pub total_focus_time: u32, // Total completed session time in seconds
    pub current_streak: u32,
    pub longest_streak: u32,
    pub named_sessions_completion_rate: f64,
    pub unnamed_sessions_completion_rate: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct SessionDatabase {
    pub sessions: Vec<SessionRecord>,
    pub version: u32,
}

impl Default for TimerState {
    fn default() -> Self {
        Self {
            duration: 25 * 60, // Default 25 minutes
            remaining: 25 * 60,
            is_running: false,
            is_paused: false,
            session_name: None,
            current_session_id: None,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WindowState {
    pub is_collapsed: bool,
    pub opacity: f64,
}

impl Default for WindowState {
    fn default() -> Self {
        Self {
            is_collapsed: false,
            opacity: 0.95,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Settings {
    pub sound_enabled: bool,
    pub volume: f64,
    pub opacity: f64,
    pub always_on_top: bool,
    pub default_duration: u32,
    pub theme: String,
    pub notification_sound: String,
    pub custom_shortcut: ShortcutConfig,
    pub watch_face: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ShortcutConfig {
    pub toggle_visibility: String,
    pub modifiers: Vec<String>,
    pub key: String,
}

impl Default for Settings {
    fn default() -> Self {
        Self {
            sound_enabled: true,
            volume: 0.5,
            opacity: 0.95,
            always_on_top: true,
            default_duration: 25 * 60,
            theme: "dark".to_string(),
            notification_sound: "zen".to_string(),
            custom_shortcut: ShortcutConfig {
                toggle_visibility: "Hyperkey+P".to_string(),
                modifiers: vec!["Super".to_string(), "Control".to_string(), "Alt".to_string(), "Shift".to_string()],
                key: "P".to_string(),
            },
            watch_face: "default".to_string(),
        }
    }
}

// Internal timer manager that holds the actual timer loop handle
#[derive(Debug)]
pub struct TimerManager {
    pub state: TimerState,
    pub timer_handle: Option<JoinHandle<()>>,
    pub last_update_time: Option<std::time::Instant>,
}

impl TimerManager {
    pub fn new() -> Self {
        Self {
            state: TimerState::default(),
            timer_handle: None,
            last_update_time: None,
        }
    }
    
    pub fn abort_timer(&mut self) {
        if let Some(handle) = self.timer_handle.take() {
            handle.abort();
        }
        self.last_update_time = None;
    }
}

type SharedTimerManager = Arc<Mutex<TimerManager>>;
type SharedWindowState = Arc<Mutex<WindowState>>;
type SharedSettings = Arc<Mutex<Settings>>;
type SharedSessionDatabase = Arc<Mutex<SessionDatabase>>;

#[tauri::command]
async fn get_timer_state(state: State<'_, SharedTimerManager>) -> Result<TimerState, String> {
    Ok(state.lock().await.state.clone())
}

#[tauri::command]
async fn set_duration(
    duration: u32,
    state: State<'_, SharedTimerManager>,
) -> Result<(), String> {
    let mut manager = state.lock().await;
    manager.state.duration = duration;
    manager.state.remaining = duration;
    Ok(())
}

#[tauri::command]
async fn start_timer(
    app_handle: tauri::AppHandle,
    state: State<'_, SharedTimerManager>,
    db: State<'_, SharedSessionDatabase>,
) -> Result<(), String> {
    let mut manager = state.lock().await;
    
    if manager.state.is_running && !manager.state.is_paused {
        return Ok(());
    }
    
    // Abort any existing timer to prevent multiple loops
    manager.abort_timer();
    
    manager.state.is_running = true;
    manager.state.is_paused = false;
    manager.last_update_time = Some(std::time::Instant::now());
    
    let timer_manager = state.inner().clone();
    let session_db = db.inner().clone();
    
    // Spawn optimized timer loop
    let handle = tauri::async_runtime::spawn(async move {
        // Use tokio::time::interval for better precision and less drift
        let mut interval = tokio::time::interval(Duration::from_millis(100)); // 100ms precision
        let mut last_second_update = std::time::Instant::now();
        let mut tray_update_counter = 0u32;
        
        loop {
            interval.tick().await;
            
            let mut manager = timer_manager.lock().await;
            
            // Exit if timer stopped or paused
            if !manager.state.is_running || manager.state.is_paused {
                break;
            }
            
            let now = std::time::Instant::now();
            
            // Only update every second to reduce CPU usage
            if now.duration_since(last_second_update).as_millis() >= 1000 {
                if manager.state.remaining > 0 {
                    manager.state.remaining -= 1;
                    last_second_update = now;
                    
                    // Emit timer update (only every second, not every 100ms)
                    app_handle.emit("timer-update", manager.state.clone()).ok();
                    
                    // Timer completion
                    if manager.state.remaining == 0 {
                        manager.state.is_running = false;
                        app_handle.emit("timer-complete", ()).ok();
                        let count = get_todays_count_from_db(&session_db).await;
                        update_tray_menu(&app_handle, &manager.state, count, false).await.ok();
                        break;
                    }
                    
                    // Update tray more frequently when window is hidden
                    tray_update_counter += 1;
                    let is_hidden = app_handle.get_webview_window("main")
                        .map(|w| !w.is_visible().unwrap_or(true))
                        .unwrap_or(true);
                    
                    let update_interval = if is_hidden { 1 } else { 15 };
                    
                    if tray_update_counter >= update_interval {
                        let count = get_todays_count_from_db(&session_db).await;
                        update_tray_menu(&app_handle, &manager.state, count, is_hidden).await.ok();
                        tray_update_counter = 0;
                    }
                }
            }
        }
    });
    
    // Store the handle to prevent multiple timers
    manager.timer_handle = Some(handle);
    
    Ok(())
}

#[tauri::command]
async fn pause_timer(state: State<'_, SharedTimerManager>) -> Result<(), String> {
    let mut manager = state.lock().await;
    manager.state.is_paused = true;
    Ok(())
}

#[tauri::command]
async fn stop_timer(state: State<'_, SharedTimerManager>) -> Result<(), String> {
    let mut manager = state.lock().await;
    
    // Abort the timer loop to immediately stop execution
    manager.abort_timer();
    
    manager.state.is_running = false;
    manager.state.is_paused = false;
    manager.state.remaining = manager.state.duration;
    Ok(())
}

#[tauri::command]
async fn toggle_collapse(
    app_handle: tauri::AppHandle,
    state: State<'_, SharedWindowState>,
) -> Result<(), String> {
    let mut window_state = state.lock().await;
    window_state.is_collapsed = !window_state.is_collapsed;
    
    if let Some(window) = app_handle.get_webview_window("main") {
        if window_state.is_collapsed {
            window.set_size(tauri::Size::Physical(tauri::PhysicalSize {
                width: 320,
                height: 64,
            })).ok();
        } else {
            window.set_size(tauri::Size::Physical(tauri::PhysicalSize {
                width: 320,
                height: 280,
            })).ok();
        }
    }
    
    app_handle.emit("window-collapsed", window_state.is_collapsed).ok();
    
    Ok(())
}

#[tauri::command]
async fn toggle_visibility(app_handle: tauri::AppHandle) -> Result<(), String> {
    if let Some(window) = app_handle.get_webview_window("main") {
        if window.is_visible().unwrap_or(false) {
            window.hide().ok();
        } else {
            window.show().ok();
            window.set_focus().ok();
        }
    }
    Ok(())
}

#[tauri::command]
async fn load_settings(
    app_handle: tauri::AppHandle,
    state: State<'_, SharedSettings>,
) -> Result<Settings, String> {
    // Try to load settings from file first
    let app_dir = app_handle.path().app_data_dir()
        .map_err(|e| format!("Failed to get app data dir: {}", e))?;
    
    let settings_path = app_dir.join("settings.json");
    
    if settings_path.exists() {
        match fs::read_to_string(&settings_path) {
            Ok(content) => {
                match serde_json::from_str::<Settings>(&content) {
                    Ok(loaded_settings) => {
                        // Update the in-memory state
                        let mut current = state.lock().await;
                        *current = loaded_settings.clone();
                        return Ok(loaded_settings);
                    }
                    Err(e) => {
                        eprintln!("Failed to parse settings: {}", e);
                    }
                }
            }
            Err(e) => {
                eprintln!("Failed to read settings file: {}", e);
            }
        }
    }
    
    // Return default settings if file doesn't exist or fails to load
    Ok(state.lock().await.clone())
}

#[tauri::command]
async fn save_settings(
    settings: Settings,
    app_handle: tauri::AppHandle,
    state: State<'_, SharedSettings>,
) -> Result<(), String> {
    // Update in-memory state
    let mut current = state.lock().await;
    *current = settings.clone();
    
    // Save to file
    let app_dir = app_handle.path().app_data_dir()
        .map_err(|e| format!("Failed to get app data dir: {}", e))?;
    
    let settings_path = app_dir.join("settings.json");
    
    // Ensure directory exists
    if let Some(parent) = settings_path.parent() {
        fs::create_dir_all(parent)
            .map_err(|e| format!("Failed to create directory: {}", e))?;
    }
    
    let json = serde_json::to_string_pretty(&settings)
        .map_err(|e| format!("Failed to serialize settings: {}", e))?;
    
    fs::write(&settings_path, json)
        .map_err(|e| format!("Failed to write settings file: {}", e))?;
    
    Ok(())
}

#[tauri::command]
async fn set_window_opacity(
    opacity: f64,
    app_handle: tauri::AppHandle,
) -> Result<(), String> {
    if let Some(window) = app_handle.get_webview_window("main") {
        #[cfg(target_os = "macos")]
        {
            #[allow(deprecated)]
            use cocoa::base::id;
            #[allow(unexpected_cfgs)]
            use objc::{msg_send, sel, sel_impl};
            
            let ns_window = window.ns_window().map_err(|e| e.to_string())? as id;
            unsafe {
                #[allow(unexpected_cfgs)]
                let _: () = msg_send![ns_window, setAlphaValue: opacity];
            }
        }
    }
    Ok(())
}

#[tauri::command]
async fn set_always_on_top(
    always_on_top: bool,
    app_handle: tauri::AppHandle,
) -> Result<(), String> {
    if let Some(window) = app_handle.get_webview_window("main") {
        window.set_always_on_top(always_on_top).map_err(|e| e.to_string())?;
    }
    Ok(())
}

#[tauri::command]
async fn open_settings_window(app_handle: tauri::AppHandle) -> Result<(), String> {
    // Check if settings window already exists
    if let Some(window) = app_handle.get_webview_window("settings") {
        // If it exists, just show and focus it
        window.show().ok();
        window.set_focus().ok();
    } else {
        // Create new settings window
        let settings_window = tauri::WebviewWindowBuilder::new(
            &app_handle,
            "settings",
            tauri::WebviewUrl::App("/settings".into()),
        )
        .title("Pomo Settings")
        .inner_size(400.0, 600.0)
        .resizable(true)
        .fullscreen(false)
        .transparent(true)
        .decorations(false)
        .always_on_top(true)
        .build()
        .map_err(|e| e.to_string())?;
        
        // Set transparency on macOS
        #[cfg(target_os = "macos")]
        {
            #[allow(deprecated)]
            use cocoa::base::id;
            #[allow(unexpected_cfgs)]
            use objc::{msg_send, sel, sel_impl};
            
            let ns_window = settings_window.ns_window().unwrap() as id;
            unsafe {
                #[allow(unexpected_cfgs)]
                let _: () = msg_send![ns_window, setAlphaValue: 0.98f64];
            }
        }
    }
    Ok(())
}

#[tauri::command]
async fn open_shortcuts_window(app_handle: tauri::AppHandle) -> Result<(), String> {
    // Check if shortcuts window already exists
    if let Some(window) = app_handle.get_webview_window("shortcuts") {
        // If it exists, just show and focus it
        window.show().ok();
        window.set_focus().ok();
    } else {
        // Create new shortcuts window
        let shortcuts_window = tauri::WebviewWindowBuilder::new(
            &app_handle,
            "shortcuts",
            tauri::WebviewUrl::App("/shortcuts".into()),
        )
        .title("Keyboard Shortcuts")
        .inner_size(700.0, 450.0)
        .resizable(true)
        .fullscreen(false)
        .transparent(true)
        .decorations(false)
        .always_on_top(true)
        .build()
        .map_err(|e| e.to_string())?;
        
        // Set transparency on macOS
        #[cfg(target_os = "macos")]
        {
            #[allow(deprecated)]
            use cocoa::base::id;
            #[allow(unexpected_cfgs)]
            use objc::{msg_send, sel, sel_impl};
            
            let ns_window = shortcuts_window.ns_window().unwrap() as id;
            unsafe {
                #[allow(unexpected_cfgs)]
                let _: () = msg_send![ns_window, setOpaque: false];
            }
        }
    }
    Ok(())
}

#[tauri::command]
async fn save_custom_watchfaces(
    watchfaces: Vec<(String, serde_json::Value)>,
    app_handle: tauri::AppHandle,
) -> Result<(), String> {
    let app_dir = app_handle.path().app_data_dir()
        .map_err(|e| format!("Failed to get app data dir: {}", e))?;
    
    let watchfaces_path = app_dir.join("custom_watchfaces.json");
    
    // Ensure directory exists
    if let Some(parent) = watchfaces_path.parent() {
        fs::create_dir_all(parent)
            .map_err(|e| format!("Failed to create directory: {}", e))?;
    }
    
    let json = serde_json::to_string_pretty(&watchfaces)
        .map_err(|e| format!("Failed to serialize watchfaces: {}", e))?;
    
    fs::write(&watchfaces_path, json)
        .map_err(|e| format!("Failed to write watchfaces file: {}", e))?;
    
    Ok(())
}

#[tauri::command]
async fn load_custom_watchfaces(
    app_handle: tauri::AppHandle,
) -> Result<Vec<(String, serde_json::Value)>, String> {
    let app_dir = app_handle.path().app_data_dir()
        .map_err(|e| format!("Failed to get app data dir: {}", e))?;
    
    let watchfaces_path = app_dir.join("custom_watchfaces.json");
    
    if !watchfaces_path.exists() {
        return Ok(Vec::new());
    }
    
    let content = fs::read_to_string(&watchfaces_path)
        .map_err(|e| format!("Failed to read watchfaces file: {}", e))?;
    
    let watchfaces: Vec<(String, serde_json::Value)> = serde_json::from_str(&content)
        .map_err(|e| format!("Failed to parse watchfaces: {}", e))?;
    
    Ok(watchfaces)
}

#[tauri::command]
async fn tray_start_timer(
    app_handle: tauri::AppHandle,
    state: State<'_, SharedTimerManager>,
    db: State<'_, SharedSessionDatabase>,
) -> Result<(), String> {
    start_timer(app_handle, state, db).await
}

#[tauri::command]
async fn tray_pause_timer(state: State<'_, SharedTimerManager>) -> Result<(), String> {
    pause_timer(state).await
}

#[tauri::command]
async fn tray_stop_timer(state: State<'_, SharedTimerManager>) -> Result<(), String> {
    stop_timer(state).await
}

#[tauri::command]
async fn set_session_name(
    name: Option<String>,
    state: State<'_, SharedTimerManager>,
) -> Result<(), String> {
    let mut manager = state.lock().await;
    manager.state.session_name = name;
    Ok(())
}

#[tauri::command]
async fn start_session_record(
    session_type: String,
    app_handle: tauri::AppHandle,
    timer_state: State<'_, SharedTimerManager>,
    db: State<'_, SharedSessionDatabase>,
) -> Result<String, String> {
    let manager = timer_state.lock().await;
    let session_id = uuid::Uuid::new_v4().to_string();
    
    let session = SessionRecord {
        id: session_id.clone(),
        name: manager.state.session_name.clone(),
        session_type,
        duration: manager.state.duration,
        actual_duration: 0,
        completed: false,
        start_time: Utc::now(),
        end_time: None,
        interrupted: false,
        pause_count: 0,
        pause_duration: 0,
    };
    
    // Add to database
    let mut database = db.lock().await;
    database.sessions.push(session);
    
    // Save to disk
    save_session_database(&app_handle, &database).await?;
    
    Ok(session_id)
}

#[tauri::command]
async fn complete_session_record(
    session_id: String,
    completed: bool,
    actual_duration: u32,
    pause_count: u32,
    pause_duration: u32,
    app_handle: tauri::AppHandle,
    db: State<'_, SharedSessionDatabase>,
) -> Result<(), String> {
    let mut database = db.lock().await;
    
    if let Some(session) = database.sessions.iter_mut().find(|s| s.id == session_id) {
        session.completed = completed;
        session.actual_duration = actual_duration;
        session.pause_count = pause_count;
        session.pause_duration = pause_duration;
        session.end_time = Some(Utc::now());
        session.interrupted = !completed;
    }
    
    // Save to disk
    save_session_database(&app_handle, &database).await?;
    
    Ok(())
}

#[tauri::command]
async fn get_session_stats(
    days: Option<u32>,
    db: State<'_, SharedSessionDatabase>,
) -> Result<SessionStats, String> {
    let database = db.lock().await;
    let cutoff_date = days.map(|d| Utc::now() - chrono::Duration::days(d as i64));
    
    let sessions: Vec<&SessionRecord> = database.sessions.iter()
        .filter(|s| {
            cutoff_date.is_none() || s.start_time >= cutoff_date.unwrap()
        })
        .collect();
    
    if sessions.is_empty() {
        return Ok(SessionStats {
            total_sessions: 0,
            completed_sessions: 0,
            completion_rate: 0.0,
            average_duration: 0.0,
            total_focus_time: 0,
            current_streak: 0,
            longest_streak: 0,
            named_sessions_completion_rate: 0.0,
            unnamed_sessions_completion_rate: 0.0,
        });
    }
    
    let total_sessions = sessions.len() as u32;
    let completed_sessions = sessions.iter().filter(|s| s.completed).count() as u32;
    let completion_rate = completed_sessions as f64 / total_sessions as f64;
    
    let completed_session_durations: Vec<u32> = sessions.iter()
        .filter(|s| s.completed)
        .map(|s| s.actual_duration)
        .collect();
    
    let average_duration = if completed_session_durations.is_empty() {
        0.0
    } else {
        completed_session_durations.iter().sum::<u32>() as f64 / completed_session_durations.len() as f64
    };
    
    let total_focus_time: u32 = completed_session_durations.iter().sum();
    
    // Calculate current streak (consecutive completed sessions from most recent)
    let mut current_streak = 0;
    let mut sorted_sessions = sessions.clone();
    sorted_sessions.sort_by(|a, b| b.start_time.cmp(&a.start_time));
    
    for session in sorted_sessions.iter() {
        if session.completed {
            current_streak += 1;
        } else {
            break;
        }
    }
    
    // Calculate longest streak
    let mut longest_streak = 0;
    let mut temp_streak = 0;
    let mut chronological_sessions = sessions.clone();
    chronological_sessions.sort_by(|a, b| a.start_time.cmp(&b.start_time));
    
    for session in chronological_sessions.iter() {
        if session.completed {
            temp_streak += 1;
            longest_streak = longest_streak.max(temp_streak);
        } else {
            temp_streak = 0;
        }
    }
    
    // Named vs unnamed completion rates
    let named_sessions: Vec<&SessionRecord> = sessions.iter().filter(|s| s.name.is_some()).copied().collect();
    let unnamed_sessions: Vec<&SessionRecord> = sessions.iter().filter(|s| s.name.is_none()).copied().collect();
    
    let named_completion_rate = if named_sessions.is_empty() {
        0.0
    } else {
        named_sessions.iter().filter(|s| s.completed).count() as f64 / named_sessions.len() as f64
    };
    
    let unnamed_completion_rate = if unnamed_sessions.is_empty() {
        0.0
    } else {
        unnamed_sessions.iter().filter(|s| s.completed).count() as f64 / unnamed_sessions.len() as f64
    };
    
    Ok(SessionStats {
        total_sessions,
        completed_sessions,
        completion_rate,
        average_duration,
        total_focus_time,
        current_streak,
        longest_streak,
        named_sessions_completion_rate: named_completion_rate,
        unnamed_sessions_completion_rate: unnamed_completion_rate,
    })
}

#[tauri::command]
async fn get_recent_sessions(
    limit: Option<u32>,
    db: State<'_, SharedSessionDatabase>,
) -> Result<Vec<SessionRecord>, String> {
    let database = db.lock().await;
    let mut sessions = database.sessions.clone();
    sessions.sort_by(|a, b| b.start_time.cmp(&a.start_time));
    
    if let Some(limit) = limit {
        sessions.truncate(limit as usize);
    }
    
    Ok(sessions)
}

#[tauri::command]
async fn get_todays_session_count(
    db: State<'_, SharedSessionDatabase>,
) -> Result<u32, String> {
    let database = db.lock().await;
    let today = Utc::now().date_naive();
    
    let count = database.sessions.iter()
        .filter(|s| s.completed && s.start_time.date_naive() == today)
        .count() as u32;
    
    Ok(count)
}

async fn save_session_database(app_handle: &tauri::AppHandle, database: &SessionDatabase) -> Result<(), String> {
    let app_dir = app_handle.path().app_data_dir()
        .map_err(|e| format!("Failed to get app data dir: {}", e))?;
    
    let db_path = app_dir.join("sessions.json");
    
    // Ensure directory exists
    if let Some(parent) = db_path.parent() {
        fs::create_dir_all(parent)
            .map_err(|e| format!("Failed to create directory: {}", e))?;
    }
    
    let json = serde_json::to_string_pretty(database)
        .map_err(|e| format!("Failed to serialize session database: {}", e))?;
    
    fs::write(&db_path, json)
        .map_err(|e| format!("Failed to write session database: {}", e))?;
    
    Ok(())
}

async fn load_session_database(app_handle: &tauri::AppHandle) -> SessionDatabase {
    let app_dir = match app_handle.path().app_data_dir() {
        Ok(dir) => dir,
        Err(_) => return SessionDatabase::default(),
    };
    
    let db_path = app_dir.join("sessions.json");
    
    if !db_path.exists() {
        return SessionDatabase::default();
    }
    
    match fs::read_to_string(&db_path) {
        Ok(content) => {
            match serde_json::from_str::<SessionDatabase>(&content) {
                Ok(database) => database,
                Err(e) => {
                    eprintln!("Failed to parse session database: {}", e);
                    SessionDatabase::default()
                }
            }
        }
        Err(e) => {
            eprintln!("Failed to read session database: {}", e);
            SessionDatabase::default()
        }
    }
}

fn generate_text_icon(text: &str, is_active: bool) -> Result<Vec<u8>, String> {
    // Use embedded Inter font for consistent rendering
    let font_bytes = include_bytes!("../assets/Inter-Medium.ttf");
    let font = Font::try_from_bytes(font_bytes)
        .ok_or("Failed to load font")?;
    
    // Calculate image size based on text
    let scale = Scale::uniform(28.0); // Slightly smaller for better fit
    let v_metrics = font.v_metrics(scale);
    
    // Measure text width
    let glyphs: Vec<_> = font.layout(text, scale, rusttype::point(0.0, 0.0)).collect();
    let text_width = glyphs
        .iter()
        .rev()
        .find_map(|g| {
            let bbox = g.pixel_bounding_box()?;
            Some(bbox.max.x)
        })
        .unwrap_or(0) as u32;
    
    let width = text_width + 10; // Add padding
    let height = 44; // Standard menu bar height for Retina (22pt * 2)
    
    // Create image with transparent background
    let mut img: RgbaImage = ImageBuffer::new(width, height);
    
    // Text color - white for dark menu bar
    let text_color = if is_active {
        Rgba([255, 255, 255, 255]) // Full white
    } else {
        Rgba([255, 255, 255, 200]) // Slightly transparent
    };
    
    // Center text vertically
    let y_pos = ((height as f32 - (v_metrics.ascent - v_metrics.descent)) / 2.0 + v_metrics.ascent) as i32;
    
    // Draw text manually using rusttype
    for glyph in glyphs {
        if let Some(bounding_box) = glyph.pixel_bounding_box() {
            glyph.draw(|x, y, v| {
                let x = (x as i32 + bounding_box.min.x + 5) as u32;
                let y = (y as i32 + bounding_box.min.y + y_pos) as u32;
                if x < width && y < height && v > 0.0 {
                    let alpha = (v * 255.0) as u8;
                    let pixel = img.get_pixel_mut(x, y);
                    pixel[0] = text_color[0];
                    pixel[1] = text_color[1];
                    pixel[2] = text_color[2];
                    pixel[3] = ((pixel[3] as u16 + alpha as u16).min(255)) as u8;
                }
            });
        }
    }
    
    // Convert to PNG bytes
    let mut png_bytes = Vec::new();
    let mut cursor = std::io::Cursor::new(&mut png_bytes);
    img.write_to(&mut cursor, image::ImageFormat::Png)
        .map_err(|e| format!("Failed to encode PNG: {:?}", e))?;
    
    Ok(png_bytes)
}


async fn get_todays_count_from_db(db: &SharedSessionDatabase) -> u32 {
    let database = db.lock().await;
    let today = Utc::now().date_naive();
    
    database.sessions.iter()
        .filter(|s| s.completed && s.start_time.date_naive() == today)
        .count() as u32
}

async fn update_tray_menu(app_handle: &tauri::AppHandle, timer_state: &TimerState, session_count: u32, is_hidden: bool) -> Result<(), String> {
    // Create the tray menu based on current timer state
    let start_pause_item = if timer_state.is_running && !timer_state.is_paused {
        MenuItem::with_id(app_handle, "pause", "Pause Timer", true, None::<&str>).map_err(|e| e.to_string())?
    } else {
        MenuItem::with_id(app_handle, "start", "Start Timer", true, None::<&str>).map_err(|e| e.to_string())?
    };
    
    let stop_item = MenuItem::with_id(app_handle, "stop", "Stop Timer", timer_state.is_running, None::<&str>).map_err(|e| e.to_string())?;
    
    // Format remaining time
    let minutes = timer_state.remaining / 60;
    let seconds = timer_state.remaining % 60;
    let time_text = if timer_state.is_running {
        format!("⏱️ {}:{:02} remaining", minutes, seconds)
    } else {
        format!("⏱️ {}:{:02} ready", timer_state.duration / 60, timer_state.duration % 60)
    };
    
    let status_item = MenuItem::with_id(app_handle, "status", time_text, false, None::<&str>).map_err(|e| e.to_string())?;
    
    let duration_5 = MenuItem::with_id(app_handle, "duration_5", "5 minutes", !timer_state.is_running, None::<&str>).map_err(|e| e.to_string())?;
    let duration_15 = MenuItem::with_id(app_handle, "duration_15", "15 minutes", !timer_state.is_running, None::<&str>).map_err(|e| e.to_string())?;
    let duration_25 = MenuItem::with_id(app_handle, "duration_25", "25 minutes", !timer_state.is_running, None::<&str>).map_err(|e| e.to_string())?;
    let duration_45 = MenuItem::with_id(app_handle, "duration_45", "45 minutes", !timer_state.is_running, None::<&str>).map_err(|e| e.to_string())?;
    
    let durations_submenu = Submenu::with_id_and_items(
        app_handle,
        "durations",
        "Quick Start",
        true,
        &[
            &duration_5,
            &duration_15,
            &duration_25,
            &duration_45,
        ]
    ).map_err(|e| e.to_string())?;
    
    let show_item = MenuItem::with_id(app_handle, "show", "Show Window", true, None::<&str>).map_err(|e| e.to_string())?;
    let settings_item = MenuItem::with_id(app_handle, "settings", "Settings", true, None::<&str>).map_err(|e| e.to_string())?;
    let quit_item = MenuItem::with_id(app_handle, "quit", "Quit", true, None::<&str>).map_err(|e| e.to_string())?;
    
    let separator = PredefinedMenuItem::separator(app_handle).map_err(|e| e.to_string())?;
    
    let mut menu_items: Vec<&dyn tauri::menu::IsMenuItem<tauri::Wry>> = vec![&status_item];
    
    // Add session name if available
    let session_item = if let Some(ref name) = timer_state.session_name {
        Some(MenuItem::with_id(app_handle, "session_name", format!("{}", name), false, None::<&str>).map_err(|e| e.to_string())?)
    } else {
        None
    };
    
    if let Some(ref item) = session_item {
        menu_items.push(item);
    }
    
    menu_items.extend_from_slice(&[
        &separator,
        &start_pause_item,
        &stop_item,
        &separator,
        &durations_submenu,
        &separator,
        &show_item,
        &settings_item,
        &separator,
        &quit_item,
    ]);
    
    let menu = Menu::with_items(app_handle, &menu_items).map_err(|e| e.to_string())?;
    
    // Update the tray icon
    if let Some(tray) = app_handle.tray_by_id("main") {
        tray.set_menu(Some(menu)).map_err(|e| e.to_string())?;
        
        // Generate dynamic icon based on timer state
        let icon_text = if timer_state.is_running && !timer_state.is_paused {
            if minutes > 0 {
                format!("{}m", minutes)
            } else {
                format!("{}s", seconds)
            }
        } else if timer_state.is_paused {
            "||".to_string()
        } else {
            "".to_string() // Empty for ready state
        };
        
        // Update icon if we have text to show
        if !icon_text.is_empty() {
            match generate_text_icon(&icon_text, timer_state.is_running && !timer_state.is_paused) {
                Ok(icon_bytes) => {
                    // Decode PNG to get dimensions
                    if let Ok(img) = image::load_from_memory(&icon_bytes) {
                        let rgba = img.to_rgba8();
                        let (width, height) = (rgba.width(), rgba.height());
                        let icon = tauri::image::Image::new(rgba.as_raw(), width, height);
                        tray.set_icon(Some(icon)).ok();
                    }
                },
                Err(e) => eprintln!("Failed to generate tray icon: {}", e),
            }
        } else {
            // Use default icon when ready
            if let Some(default_icon) = app_handle.default_window_icon() {
                tray.set_icon(Some(default_icon.clone())).ok();
            }
        }
        
        // Update tooltip with session count and show more detail when hidden
        let tooltip = if timer_state.is_running && !timer_state.is_paused {
            if is_hidden {
                // Show minute-level progress when hidden
                let progress_percentage = ((timer_state.duration - timer_state.remaining) as f32 / timer_state.duration as f32 * 100.0) as u32;
                format!("Pomo - {}m left ({}%) | {} sessions today", 
                    if minutes > 0 { minutes } else { 1 }, // Show at least 1m
                    progress_percentage,
                    session_count
                )
            } else {
                format!("Pomo - Running ({}:{:02}) | {} sessions today", minutes, seconds, session_count)
            }
        } else if timer_state.is_paused {
            format!("Pomo - Paused ({}:{:02}) | {} sessions today", minutes, seconds, session_count)
        } else {
            format!("Pomo - Ready | {} sessions today", session_count)
        };
        
        tray.set_tooltip(Some(&tooltip)).map_err(|e| e.to_string())?;
    }
    
    Ok(())
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let timer_manager = Arc::new(Mutex::new(TimerManager::new()));
    let window_state = Arc::new(Mutex::new(WindowState::default()));
    let settings = Arc::new(Mutex::new(Settings::default()));
    let session_database = Arc::new(Mutex::new(SessionDatabase::default()));

    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_fs::init())
        .plugin(
            tauri_plugin_global_shortcut::Builder::new()
                .with_handler(|app, shortcut, event| {
                    if event.state == ShortcutState::Pressed {
                        let hyperkey_p = Shortcut::new(
                            Some(Modifiers::SUPER | Modifiers::CONTROL | Modifiers::ALT | Modifiers::SHIFT),
                            Code::KeyP
                        );
                        
                        if shortcut == &hyperkey_p {
                            app.emit("toggle-visibility", ()).ok();
                        }
                    }
                })
                .build()
        )
        .manage(timer_manager.clone())
        .manage(window_state)
        .manage(settings)
        .manage(session_database.clone())
        .invoke_handler(tauri::generate_handler![
            get_timer_state,
            set_duration,
            start_timer,
            pause_timer,
            stop_timer,
            toggle_collapse,
            toggle_visibility,
            load_settings,
            save_settings,
            set_window_opacity,
            set_always_on_top,
            open_settings_window,
            open_shortcuts_window,
            save_custom_watchfaces,
            load_custom_watchfaces,
            tray_start_timer,
            tray_pause_timer,
            tray_stop_timer,
            set_session_name,
            start_session_record,
            complete_session_record,
            get_session_stats,
            get_recent_sessions,
            get_todays_session_count,
        ])
        .setup(move |app| {
            let app_handle = app.handle().clone();
            
            // Setup system tray
            let _tray = TrayIconBuilder::with_id("main")
                .tooltip("Pomo - Ready")
                .icon(app.default_window_icon().unwrap().clone())
                .on_menu_event({
                    let timer_manager_clone = timer_manager.clone();
                    let app_handle_clone = app_handle.clone();
                    let session_db_clone = session_database.clone();
                    move |_app, event| {
                        let app_handle = app_handle_clone.clone();
                        let timer_manager = timer_manager_clone.clone();
                        let session_db = session_db_clone.clone();
                        
                        tauri::async_runtime::spawn(async move {
                            match event.id.as_ref() {
                                "start" => {
                                    // Use the optimized start_timer function
                                    let mut manager = timer_manager.lock().await;
                                    
                                    if manager.state.is_running && !manager.state.is_paused {
                                        return;
                                    }
                                    
                                    // Abort any existing timer to prevent multiple loops
                                    manager.abort_timer();
                                    
                                    manager.state.is_running = true;
                                    manager.state.is_paused = false;
                                    
                                    let timer_manager_for_loop = timer_manager.clone();
                                    let app_handle_for_loop = app_handle.clone();
                                    let session_db_for_loop = session_db.clone();
                                    
                                    // Use the same optimized timer loop as start_timer
                                    let handle = tauri::async_runtime::spawn(async move {
                                        let mut interval = tokio::time::interval(Duration::from_millis(100));
                                        let mut last_second_update = std::time::Instant::now();
                                        let mut tray_update_counter = 0u32;
                                        
                                        loop {
                                            interval.tick().await;
                                            
                                            let mut manager = timer_manager_for_loop.lock().await;
                                            
                                            if !manager.state.is_running || manager.state.is_paused {
                                                break;
                                            }
                                            
                                            let now = std::time::Instant::now();
                                            
                                            if now.duration_since(last_second_update).as_millis() >= 1000 {
                                                if manager.state.remaining > 0 {
                                                    manager.state.remaining -= 1;
                                                    last_second_update = now;
                                                    
                                                    app_handle_for_loop.emit("timer-update", manager.state.clone()).ok();
                                                    
                                                    if manager.state.remaining == 0 {
                                                        manager.state.is_running = false;
                                                        app_handle_for_loop.emit("timer-complete", ()).ok();
                                                        let count = get_todays_count_from_db(&session_db_for_loop).await;
                                                        update_tray_menu(&app_handle_for_loop, &manager.state, count, false).await.ok();
                                                        break;
                                                    }
                                                    
                                                    tray_update_counter += 1;
                                                    if tray_update_counter >= 15 {
                                                        let count = get_todays_count_from_db(&session_db_for_loop).await;
                                                        update_tray_menu(&app_handle_for_loop, &manager.state, count, false).await.ok();
                                                        tray_update_counter = 0;
                                                    }
                                                }
                                            }
                                        }
                                    });
                                    
                                    manager.timer_handle = Some(handle);
                                    let count = get_todays_count_from_db(&session_db).await;
                                    update_tray_menu(&app_handle, &manager.state, count, false).await.ok();
                                }
                                "pause" => {
                                    let mut manager = timer_manager.lock().await;
                                    manager.state.is_paused = true;
                                    let count = get_todays_count_from_db(&session_db).await;
                                    update_tray_menu(&app_handle, &manager.state, count, false).await.ok();
                                }
                                "stop" => {
                                    let mut manager = timer_manager.lock().await;
                                    manager.abort_timer();
                                    manager.state.is_running = false;
                                    manager.state.is_paused = false;
                                    manager.state.remaining = manager.state.duration;
                                    let count = get_todays_count_from_db(&session_db).await;
                                    update_tray_menu(&app_handle, &manager.state, count, false).await.ok();
                                }
                                "duration_5" => {
                                    let mut manager = timer_manager.lock().await;
                                    manager.state.duration = 5 * 60;
                                    manager.state.remaining = 5 * 60;
                                    let count = get_todays_count_from_db(&session_db).await;
                                    update_tray_menu(&app_handle, &manager.state, count, false).await.ok();
                                }
                                "duration_15" => {
                                    let mut manager = timer_manager.lock().await;
                                    manager.state.duration = 15 * 60;
                                    manager.state.remaining = 15 * 60;
                                    let count = get_todays_count_from_db(&session_db).await;
                                    update_tray_menu(&app_handle, &manager.state, count, false).await.ok();
                                }
                                "duration_25" => {
                                    let mut manager = timer_manager.lock().await;
                                    manager.state.duration = 25 * 60;
                                    manager.state.remaining = 25 * 60;
                                    let count = get_todays_count_from_db(&session_db).await;
                                    update_tray_menu(&app_handle, &manager.state, count, false).await.ok();
                                }
                                "duration_45" => {
                                    let mut manager = timer_manager.lock().await;
                                    manager.state.duration = 45 * 60;
                                    manager.state.remaining = 45 * 60;
                                    let count = get_todays_count_from_db(&session_db).await;
                                    update_tray_menu(&app_handle, &manager.state, count, false).await.ok();
                                }
                                "show" => {
                                    if let Some(window) = app_handle.get_webview_window("main") {
                                        window.show().ok();
                                        window.set_focus().ok();
                                    }
                                }
                                "settings" => {
                                    open_settings_window(app_handle.clone()).await.ok();
                                }
                                "quit" => {
                                    app_handle.exit(0);
                                }
                                _ => {}
                            }
                        });
                    }
                })
                .build(app)?;
            
            // Initialize tray menu
            let app_handle_tray = app_handle.clone();
            let timer_manager_tray = timer_manager.clone();
            let session_db_tray = session_database.clone();
            tauri::async_runtime::spawn(async move {
                let manager = timer_manager_tray.lock().await;
                let count = get_todays_count_from_db(&session_db_tray).await;
                update_tray_menu(&app_handle_tray, &manager.state, count, false).await.ok();
            });
            
            // Note: Periodic tray updates are now handled more efficiently within the timer loop itself
            // This eliminates the need for a separate periodic task that wastes CPU cycles
            
            // Load session database from disk
            let session_db_state = session_database.clone();
            let app_handle_db = app_handle.clone();
            tauri::async_runtime::spawn(async move {
                let loaded_db = load_session_database(&app_handle_db).await;
                let mut db = session_db_state.lock().await;
                *db = loaded_db;
                println!("✅ Loaded {} sessions from database", db.sessions.len());
            });
            
            // Load settings from file on startup
            let settings_state = app.state::<SharedSettings>();
            let app_dir = app_handle.path().app_data_dir().ok();
            
            if let Some(dir) = app_dir {
                let settings_path = dir.join("settings.json");
                if settings_path.exists() {
                    if let Ok(content) = fs::read_to_string(&settings_path) {
                        if let Ok(loaded_settings) = serde_json::from_str::<Settings>(&content) {
                            // Update the settings state with loaded settings
                            if let Ok(mut settings) = settings_state.try_lock() {
                                *settings = loaded_settings.clone();
                                println!("✅ Loaded settings from file");
                            }
                        }
                    }
                }
            }
            
            // Register global shortcut
            let shortcut_manager = app_handle.global_shortcut();
            let hyperkey_p = Shortcut::new(
                Some(Modifiers::SUPER | Modifiers::CONTROL | Modifiers::ALT | Modifiers::SHIFT),
                Code::KeyP
            );
            
            match shortcut_manager.register(hyperkey_p) {
                Ok(_) => println!("✅ Registered global shortcut: Hyperkey+P"),
                Err(e) => eprintln!("❌ Failed to register shortcut: {}", e),
            }
            
            // Apply initial window settings
            if let Some(window) = app.get_webview_window("main") {
                // Get current settings (either loaded from file or defaults)
                let opacity = if let Ok(settings) = settings_state.try_lock() {
                    settings.opacity
                } else {
                    0.95
                };
                
                // Set transparency on macOS
                #[cfg(target_os = "macos")]
                {
                    #[allow(deprecated)]
                    use cocoa::base::id;
                    #[allow(unexpected_cfgs)]
                    use objc::{msg_send, sel, sel_impl};
                    
                    let ns_window = window.ns_window().unwrap() as id;
                    unsafe {
                        #[allow(unexpected_cfgs)]
                        let _: () = msg_send![ns_window, setAlphaValue: opacity];
                    }
                }
                
                // Set always on top from settings
                if let Ok(settings) = settings_state.try_lock() {
                    window.set_always_on_top(settings.always_on_top).ok();
                }
                
                // Handle window close request - hide window instead of quitting
                let window_clone = window.clone();
                window.on_window_event(move |event| {
                    if let tauri::WindowEvent::CloseRequested { api, .. } = event {
                        api.prevent_close();
                        window_clone.hide().ok();
                    }
                });
            }
            
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}