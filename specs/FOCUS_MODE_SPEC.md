# 🎯 Focus Mode Feature Specification

## Overview

Focus Mode is a comprehensive distraction-blocking system that activates during Pomodoro sessions to help users maintain deep focus. It combines website blocking via browser extensions with optional Apple Focus mode integration for a seamless productivity experience.

## Goals

### Primary Goals
- **Eliminate digital distractions** during focus sessions
- **Seamless integration** with existing Pomo timer workflow
- **Cross-platform compatibility** with graceful degradation
- **User control** over blocking strictness and rules

### Secondary Goals
- **Apple ecosystem integration** via Focus modes API
- **Session-type aware blocking** (different rules for different session types)
- **Smart break management** (temporary access during breaks)

## Feature Phases

### Phase 1: Browser Extension Website Blocking
**Timeline:** 2-3 weeks  
**Dependencies:** None  
**Risk:** Low

Core website blocking functionality via browser extensions.

### Phase 2: Apple Focus Integration  
**Timeline:** 1-2 weeks  
**Dependencies:** Phase 1 complete  
**Risk:** Medium (API availability)

Integration with macOS/iOS Focus modes for system-level blocking.

### Phase 3: Advanced Rules & Management
**Timeline:** 2-3 weeks  
**Dependencies:** Phase 1 complete  
**Risk:** Low

Smart rules, scheduling, and advanced configuration options.

---

## Phase 1: Browser Extension Website Blocking

### User Stories

#### US1: Basic Website Blocking
```
As a user, I want to block distracting websites during my focus sessions
So that I can maintain concentration without manual willpower
```

**Acceptance Criteria:**
- [ ] User can configure list of websites to block
- [ ] Websites are blocked only during active timer sessions
- [ ] Blocked sites show focus reminder instead of content
- [ ] User can temporarily override block with confirmation delay
- [ ] Blocking automatically disables when session ends

#### US2: Browser Extension Installation
```
As a user, I want easy setup of website blocking
So that I can start using focus mode without technical complexity
```

**Acceptance Criteria:**
- [ ] Pomo detects if browser extensions are installed
- [ ] Clear installation instructions with direct links
- [ ] Extension auto-connects to running Pomo app
- [ ] Graceful fallback when extensions not available

#### US3: Session-Aware Blocking
```
As a user, I want different blocking rules for different session types
So that I can allow research sites during "Planning" but block everything during "Deep Work"
```

**Acceptance Criteria:**
- [ ] Blocking rules can be configured per session type
- [ ] Rules apply automatically based on current session
- [ ] Default rule sets for common session types
- [ ] Visual indication of active blocking level

### Technical Architecture

#### Communication Protocol
```
Pomo App ↔ Browser Extension Communication:

Method 1: Local HTTP Server (Recommended)
- Pomo runs HTTP server on localhost:3456
- Extension polls /focus-status endpoint every 5 seconds
- Simple JSON API for rules and status

Method 2: File-based Communication
- Pomo writes focus-rules.json to known location
- Extension monitors file for changes
- More reliable but slower updates
```

#### Data Structures
```typescript
interface FocusSession {
  active: boolean;
  sessionName: string;
  sessionType: SessionType;
  timeRemaining: number;
  rules: FocusRule[];
}

interface FocusRule {
  id: string;
  name: string;
  sessionTypes: SessionType[];
  blockedDomains: string[];
  strictness: 'gentle' | 'firm' | 'strict';
  allowOverride: boolean;
  overrideDelay: number; // seconds
}

interface BlockedPageConfig {
  title: string;
  message: string;
  showTimeRemaining: boolean;
  showOverrideButton: boolean;
  customCSS?: string;
}
```

### Browser Extension Implementation

#### Chrome Extension Manifest
```json
{
  "manifest_version": 3,
  "name": "Pomo Focus Mode",
  "version": "1.0",
  "permissions": [
    "webRequest",
    "webRequestBlocking",
    "activeTab",
    "storage"
  ],
  "host_permissions": ["<all_urls>"],
  "background": {
    "service_worker": "background.js"
  },
  "content_scripts": [{
    "matches": ["<all_urls>"],
    "js": ["content.js"]
  }]
}
```

#### Core Blocking Logic
```javascript
// background.js
class FocusManager {
  constructor() {
    this.focusSession = null;
    this.pollInterval = 5000;
    this.startPolling();
  }

  async fetchFocusStatus() {
    try {
      const response = await fetch('http://localhost:3456/focus-status');
      const session = await response.json();
      this.updateFocusSession(session);
    } catch (error) {
      // Pomo app not running, disable blocking
      this.focusSession = null;
    }
  }

  updateFocusSession(session) {
    this.focusSession = session;
    this.updateBlockingRules();
  }

  updateBlockingRules() {
    chrome.webRequest.onBeforeRequest.removeListener(this.blockHandler);
    
    if (this.focusSession?.active) {
      chrome.webRequest.onBeforeRequest.addListener(
        this.blockHandler.bind(this),
        { urls: ["<all_urls>"] },
        ["blocking"]
      );
    }
  }

  blockHandler(details) {
    const domain = new URL(details.url).hostname;
    const blocked = this.isBlocked(domain);
    
    if (blocked) {
      return {
        redirectUrl: chrome.runtime.getURL('blocked.html') + 
          `?domain=${domain}&session=${this.focusSession.sessionName}`
      };
    }
  }

  isBlocked(domain) {
    if (!this.focusSession?.active) return false;
    
    return this.focusSession.rules.some(rule => 
      rule.sessionTypes.includes(this.focusSession.sessionType) &&
      rule.blockedDomains.some(blocked => 
        domain.includes(blocked) || blocked.includes(domain)
      )
    );
  }
}
```

#### Blocked Page Interface
```html
<!-- blocked.html -->
<!DOCTYPE html>
<html>
<head>
  <title>Focus Mode Active</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
      text-align: center;
      padding: 2rem;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      justify-content: center;
    }
    .focus-container {
      max-width: 500px;
      margin: 0 auto;
    }
    .timer {
      font-size: 3rem;
      font-weight: 300;
      margin: 1rem 0;
    }
    .override-btn {
      background: rgba(255,255,255,0.2);
      border: 1px solid rgba(255,255,255,0.3);
      color: white;
      padding: 0.75rem 1.5rem;
      border-radius: 8px;
      margin-top: 2rem;
      cursor: pointer;
    }
  </style>
</head>
<body>
  <div class="focus-container">
    <h1>🎯 Focus Mode Active</h1>
    <p id="session-info">Deep Work Session</p>
    <div id="timer" class="timer">23:45</div>
    <p>This site is blocked during your focus session.</p>
    <button id="override-btn" class="override-btn" style="display: none;">
      Break Focus (Hold for 5s)
    </button>
  </div>
  <script src="blocked.js"></script>
</body>
</html>
```

### Pomo App Integration

#### Focus Mode Service
```typescript
// src/services/focus-mode.ts
export class FocusModeService {
  private server: http.Server | null = null;
  private currentSession: FocusSession | null = null;
  
  async startFocusSession(session: FocusSession) {
    this.currentSession = session;
    await this.startLocalServer();
    await this.notifyExtensions();
  }

  async endFocusSession() {
    this.currentSession = null;
    await this.notifyExtensions();
  }

  private async startLocalServer() {
    if (this.server) return;
    
    const app = express();
    app.get('/focus-status', (req, res) => {
      res.json(this.currentSession || { active: false });
    });
    
    this.server = app.listen(3456);
  }

  private async notifyExtensions() {
    // Extensions will poll the server
    // Could also broadcast via WebSocket for real-time updates
  }
}
```

#### Settings Integration
```typescript
// Add to settings store
interface FocusModeSettings {
  enabled: boolean;
  defaultRules: FocusRule[];
  extensionStatus: {
    chrome: 'installed' | 'not-installed' | 'unknown';
    firefox: 'installed' | 'not-installed' | 'unknown';
    safari: 'installed' | 'not-installed' | 'unknown';
  };
}
```

### User Interface

#### Focus Mode Settings Panel
```tsx
// src/components/settings/FocusModePanel.tsx
export function FocusModePanel() {
  return (
    <div className="space-y-6">
      <div>
        <h3>Focus Mode</h3>
        <p>Block distracting websites during focus sessions</p>
      </div>

      <ExtensionStatus />
      
      <SessionRulesEditor />
      
      <BlockedSitesManager />
      
      <StrictnessSelector />
    </div>
  );
}
```

#### Extension Status Component
```tsx
function ExtensionStatus() {
  const { extensionStatus } = useFocusModeSettings();
  
  return (
    <div className="bg-muted/20 rounded-lg p-4">
      <h4>Browser Extensions</h4>
      <div className="space-y-2">
        {Object.entries(extensionStatus).map(([browser, status]) => (
          <div key={browser} className="flex items-center justify-between">
            <span>{browser.charAt(0).toUpperCase() + browser.slice(1)}</span>
            {status === 'installed' ? (
              <Badge variant="success">Installed</Badge>
            ) : (
              <Button 
                size="sm" 
                onClick={() => openExtensionStore(browser)}
              >
                Install
              </Button>
            )}
          </div>
        ))}
      </div>
    </div>
  );
}
```

### Testing Strategy

#### Unit Tests
- [ ] Focus rule matching logic
- [ ] Domain blocking algorithms
- [ ] Session state management
- [ ] Local server API endpoints

#### Integration Tests
- [ ] Pomo app ↔ extension communication
- [ ] Session start/stop flows
- [ ] Rule application during different session types
- [ ] Graceful degradation without extensions

#### Manual Testing
- [ ] Extension installation flow
- [ ] Website blocking during active sessions
- [ ] Override functionality with delay
- [ ] Multiple browser support
- [ ] Session type switching

---

## Phase 2: Apple Focus Integration

### User Stories

#### US4: Apple Focus Activation
```
As a macOS user, I want Pomo to automatically enable my "Work" Focus mode
So that system-wide notifications and distractions are minimized
```

#### US5: Smart Focus Selection
```
As a user, I want Pomo to choose the appropriate Focus mode for different session types
So that my system configuration matches my work context
```

### Technical Implementation

#### Focus Mode API Integration
```swift
// Focus.swift - Native module for Tauri
import Intents

@available(macOS 12.0, *)
class FocusManager {
  func enableFocus(mode: String) async throws {
    let intent = INSetFocusStatusIntent()
    intent.focusStatus = INFocusStatus(isFocused: true)
    
    // This requires user permission and setup
    let response = try await intent.perform()
    // Handle response
  }
}
```

#### Rust Bridge
```rust
// src-tauri/src/focus.rs
#[cfg(target_os = "macos")]
#[tauri::command]
async fn enable_apple_focus(mode: String) -> Result<(), String> {
  // Call Swift function via FFI or subprocess
  // Handle permissions and errors
  Ok(())
}
```

---

## Phase 3: Advanced Rules & Management

### User Stories

#### US6: Time-based Rules
```
As a user, I want different blocking rules at different times of day
So that I can allow social media during lunch but block it during morning deep work
```

#### US7: Break Exceptions
```
As a user, I want certain sites accessible during breaks
So that I can check messages or news during my 5-minute breaks
```

### Advanced Features
- [ ] Scheduling and time-based rules
- [ ] Temporary break permissions
- [ ] Productivity scoring based on focus adherence
- [ ] Focus session analytics and insights

---

## Success Metrics

### Engagement Metrics
- **Focus Mode Adoption Rate:** % of users who enable focus mode
- **Session Completion Rate:** % increase in completed vs abandoned sessions
- **Block Override Rate:** How often users break focus (lower is better)

### Performance Metrics
- **Extension Communication Latency:** < 100ms for status updates
- **Block Response Time:** < 50ms from request to redirect
- **Resource Usage:** Extension memory < 10MB

### User Experience Metrics
- **Setup Completion Rate:** % of users who successfully install extensions
- **Feature Discovery:** How users find and enable focus mode
- **Support Tickets:** Focus mode related issues

---

## Risk Assessment

### High Risk
- **Browser Extension Store Approval:** Chrome/Firefox stores may reject or delay
- **API Changes:** Browser APIs or Apple Focus APIs may change
- **Performance Impact:** Extension affecting browser performance

### Medium Risk
- **Cross-browser Compatibility:** Different extension APIs and behaviors
- **User Permissions:** Users may not grant required permissions
- **Network Connectivity:** Local server communication issues

### Low Risk
- **UI Complexity:** Settings interface becoming too complex
- **Default Rules:** Choosing appropriate default blocked sites

---

## Implementation Timeline

### Week 1-2: Foundation
- [ ] Design and implement local HTTP server
- [ ] Create basic Chrome extension
- [ ] Establish communication protocol
- [ ] Basic website blocking functionality

### Week 3-4: Polish & Multi-browser
- [ ] Firefox extension
- [ ] Safari extension (if feasible)
- [ ] Blocked page design and functionality
- [ ] Override mechanism with delays

### Week 5-6: Integration & Testing
- [ ] Pomo app UI for focus mode settings
- [ ] Session-type aware rules
- [ ] Comprehensive testing across browsers
- [ ] Error handling and edge cases

### Week 7 (Optional): Apple Focus
- [ ] Research Apple Focus API availability
- [ ] Implement basic Focus mode activation
- [ ] Test on macOS systems
- [ ] Documentation and user guides

---

## Future Enhancements

### Advanced Blocking
- **Application blocking** (hide/minimize distracting apps)
- **Network-level blocking** (router integration)
- **Productivity scoring** based on focus adherence

### Social Features
- **Team focus sessions** (shared blocking rules)
- **Focus accountability** (share progress with friends)
- **Leaderboards** for focus streaks

### AI Integration
- **Smart rule suggestions** based on browsing patterns
- **Adaptive blocking** that learns from user behavior
- **Distraction prediction** and preemptive blocking

---

*This specification is a living document and will be updated as we learn from user feedback and technical constraints.*