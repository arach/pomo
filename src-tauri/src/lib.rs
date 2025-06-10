use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tauri::{Emitter, Manager, State};
use tauri_plugin_global_shortcut::{GlobalShortcutExt, Code, Modifiers, Shortcut, ShortcutState};
use tokio::sync::Mutex;
use std::time::Duration;

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

type SharedTimerState = Arc<Mutex<TimerState>>;
type SharedWindowState = Arc<Mutex<WindowState>>;

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
                width: 300,
                height: 60,
            })).ok();
        } else {
            window.set_size(tauri::Size::Physical(tauri::PhysicalSize {
                width: 300,
                height: 200,
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

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let timer_state = Arc::new(Mutex::new(TimerState::default()));
    let window_state = Arc::new(Mutex::new(WindowState::default()));

    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
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
        .invoke_handler(tauri::generate_handler![
            get_timer_state,
            set_duration,
            start_timer,
            pause_timer,
            stop_timer,
            toggle_collapse,
            toggle_visibility,
        ])
        .setup(|app| {
            let app_handle = app.handle().clone();
            
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
                // Set transparency on macOS
                #[cfg(target_os = "macos")]
                {
                    use cocoa::base::id;
                    use objc::{msg_send, sel, sel_impl};
                    
                    let ns_window = window.ns_window().unwrap() as id;
                    unsafe {
                        let _: () = msg_send![ns_window, setAlphaValue: 0.95f64];
                    }
                }
            }
            
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}