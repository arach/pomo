#![allow(deprecated)] // Allow deprecated warnings for cocoa::base::id until migration to objc2

use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tauri::{Emitter, Manager, State};
use tauri_plugin_global_shortcut::{GlobalShortcutExt, Code, Modifiers, Shortcut, ShortcutState};
use tokio::sync::Mutex;
use std::time::Duration;
use std::fs;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TimerState {
    pub duration: u32, // Duration in seconds
    pub remaining: u32, // Remaining time in seconds
    pub is_running: bool,
    pub is_paused: bool,
}

impl Default for TimerState {
    fn default() -> Self {
        Self {
            duration: 25 * 60, // Default 25 minutes
            remaining: 25 * 60,
            is_running: false,
            is_paused: false,
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
            notification_sound: "default".to_string(),
            custom_shortcut: ShortcutConfig {
                toggle_visibility: "Hyperkey+P".to_string(),
                modifiers: vec!["Super".to_string(), "Control".to_string(), "Alt".to_string(), "Shift".to_string()],
                key: "P".to_string(),
            },
            watch_face: "default".to_string(),
        }
    }
}

type SharedTimerState = Arc<Mutex<TimerState>>;
type SharedWindowState = Arc<Mutex<WindowState>>;
type SharedSettings = Arc<Mutex<Settings>>;

#[tauri::command]
async fn get_timer_state(state: State<'_, SharedTimerState>) -> Result<TimerState, String> {
    Ok(state.lock().await.clone())
}

#[tauri::command]
async fn set_duration(
    duration: u32,
    state: State<'_, SharedTimerState>,
) -> Result<(), String> {
    let mut timer = state.lock().await;
    timer.duration = duration;
    timer.remaining = duration;
    Ok(())
}

#[tauri::command]
async fn start_timer(
    app_handle: tauri::AppHandle,
    state: State<'_, SharedTimerState>,
) -> Result<(), String> {
    let mut timer = state.lock().await;
    
    if timer.is_running && !timer.is_paused {
        return Ok(());
    }
    
    timer.is_running = true;
    timer.is_paused = false;
    
    let timer_state = state.inner().clone();
    
    // Spawn timer loop
    tauri::async_runtime::spawn(async move {
        loop {
            tokio::time::sleep(Duration::from_secs(1)).await;
            
            let mut timer = timer_state.lock().await;
            
            if !timer.is_running || timer.is_paused {
                break;
            }
            
            if timer.remaining > 0 {
                timer.remaining -= 1;
                app_handle.emit("timer-update", timer.clone()).ok();
                
                if timer.remaining == 0 {
                    timer.is_running = false;
                    app_handle.emit("timer-complete", ()).ok();
                    break;
                }
            }
        }
    });
    
    Ok(())
}

#[tauri::command]
async fn pause_timer(state: State<'_, SharedTimerState>) -> Result<(), String> {
    let mut timer = state.lock().await;
    timer.is_paused = true;
    Ok(())
}

#[tauri::command]
async fn stop_timer(state: State<'_, SharedTimerState>) -> Result<(), String> {
    let mut timer = state.lock().await;
    timer.is_running = false;
    timer.is_paused = false;
    timer.remaining = timer.duration;
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
                height: 80,
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

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let timer_state = Arc::new(Mutex::new(TimerState::default()));
    let window_state = Arc::new(Mutex::new(WindowState::default()));
    let settings = Arc::new(Mutex::new(Settings::default()));

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
        .manage(timer_state)
        .manage(window_state)
        .manage(settings)
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
        ])
        .setup(|app| {
            let app_handle = app.handle().clone();
            
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
            }
            
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}