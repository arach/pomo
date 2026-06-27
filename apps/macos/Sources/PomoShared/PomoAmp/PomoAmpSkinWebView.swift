import SwiftUI
import WebKit

struct PomoAmpSkinWebView: NSViewRepresentable {
    let skin: PomoAmpSkin
    let state: PomoAmpSkinState
    let viz: PomoAmpVizData
    let profile: PomoAmpVisualizerProfile
    var onAction: (PomoAmpSkinAction) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onAction: onAction)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        config.userContentController.add(context.coordinator, name: "yamp")
        config.userContentController.addUserScript(
            WKUserScript(source: Self.bridgeJS, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        )

        let webView = DraggableSkinWebView(frame: .zero, configuration: config)
        WebKitInspectorMenu.enableInspection(on: webView)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        context.coordinator.webView = webView
        context.coordinator.skinDirectory = skin.directory
        context.coordinator.state = state
        context.coordinator.viz = viz
        context.coordinator.profile = profile
        webView.loadFileURL(skin.entryURL, allowingReadAccessTo: skin.directory)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.onAction = onAction
        context.coordinator.state = state
        context.coordinator.viz = viz
        context.coordinator.profile = profile
        context.coordinator.sendProfile()
        context.coordinator.sendState()
        context.coordinator.sendViz()
    }

    static let bridgeJS = """
    (function(){
      if (window.yamp) return;
      var listeners = [];
      var vizListeners = [];
      var profileListeners = [];
      var dragListeners = [];
      var latestState = null;
      var latestViz = null;
      var latestProfile = null;
      var latestDrag = {
        active: false,
        phase: "end",
        x: 0,
        y: 0,
        width: 0,
        height: 0,
        dx: 0,
        dy: 0,
        totalDx: 0,
        totalDy: 0,
        velocityX: 0,
        velocityY: 0,
        speed: 0,
        directionX: 0,
        directionY: 0,
        angleDegrees: 0
      };
      var lastVideoMouseDownActionAt = 0;
      function post(message) {
        try { window.webkit.messageHandlers.yamp.postMessage(message); } catch (e) {}
      }
      function log(message, detail) {
        try { console.log("[PomoAmpSkin]", message, detail || ""); } catch (e) {}
        post({ type: "log", message: String(message || ""), detail: detail || {} });
      }
      function closestElement(target, selector) {
        var element = target && target.nodeType === 1 ? target : target && target.parentElement;
        return element && element.closest ? element.closest(selector) : null;
      }
      function actionNameFor(element) {
        if (element && element.id === "video") return "toggleVideo";
        var action = String(element && element.getAttribute && element.getAttribute("data-action") || "");
        return action;
      }
      function postActionForButton(action, source, button, event) {
        log(source, {
          id: button.id || "",
          action: action,
          text: (button.textContent || "").trim(),
          dataAction: button.getAttribute("data-action") || "",
          disabled: !!button.disabled,
          x: event.clientX,
          y: event.clientY
        });
        post({ type: "action", name: action });
      }
      document.addEventListener("mousedown", function(event) {
        var button = closestElement(event.target, "button#video,#video[data-action]");
        if (!button || button.disabled) return;
        var action = actionNameFor(button);
        if (!action) return;
        lastVideoMouseDownActionAt = Date.now();
        event.preventDefault();
        event.stopImmediatePropagation();
        postActionForButton(action, "bridge-video-mousedown", button, event);
      }, true);
      document.addEventListener("click", function(event) {
        var button = closestElement(event.target, "button#video,#video[data-action]");
        if (!button || button.disabled) return;
        var action = actionNameFor(button);
        if (!action) return;
        event.preventDefault();
        event.stopImmediatePropagation();
        if (Date.now() - lastVideoMouseDownActionAt < 650) {
          log("bridge-video-click-suppressed", {
            id: button.id || "",
            action: action,
            text: (button.textContent || "").trim(),
            x: event.clientX,
            y: event.clientY
          });
          return;
        }
        postActionForButton(action, "bridge-capture-click", button, event);
      }, true);
      window.__yampReceiveState = function(state) {
        latestState = state;
        listeners.slice().forEach(function(listener){
          try { listener(state); } catch (e) {}
        });
      };
      window.__yampReceiveViz = function(viz) {
        latestViz = viz;
        vizListeners.slice().forEach(function(listener){
          try { listener(viz); } catch (e) {}
        });
      };
      window.__yampReceiveProfile = function(profile) {
        latestProfile = profile;
        profileListeners.slice().forEach(function(listener){
          try { listener(profile); } catch (e) {}
        });
      };
      window.__yampReceiveDrag = function(event) {
        if (typeof event === "boolean") {
          latestDrag = Object.assign({}, latestDrag, { active: event });
        } else {
          latestDrag = Object.assign({}, latestDrag, event || {});
        }
        dragListeners.slice().forEach(function(listener){
          try { listener(latestDrag); } catch (e) {}
        });
      };
      window.yamp = Object.freeze({
        version: "html@1",
        ready: function(){
          log("ready", { href: String(location.href || "") });
          post({ type: "ready" });
        },
        action: function(name){
          var action = String(name || "");
          if (!action) return false;
          log("pomo-amp-action-call", { action: action });
          post({ type: "action", name: action });
          return true;
        },
        log: function(message, detail) {
          log(message, detail || {});
        },
        onState: function(listener) {
          if (typeof listener !== "function") return;
          listeners.push(listener);
          if (latestState) listener(latestState);
        },
        onViz: function(listener) {
          if (typeof listener !== "function") return;
          vizListeners.push(listener);
          if (latestViz) listener(latestViz);
        },
        onScope: function(listener) {
          if (typeof listener !== "function") return;
          vizListeners.push(listener);
          if (latestViz) listener(latestViz);
        },
        onProfile: function(listener) {
          if (typeof listener !== "function") return;
          profileListeners.push(listener);
          if (latestProfile) listener(latestProfile);
        },
        onDrag: function(listener) {
          if (typeof listener !== "function") return;
          dragListeners.push(listener);
          listener(latestDrag);
        }
      });
    })();
    """

    final class DraggableSkinWebView: WKWebView {
        override var mouseDownCanMoveWindow: Bool { false }

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
            true
        }

        override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
            WebKitInspectorMenu.addOpenInspectorItem(to: menu, webView: self)
        }
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        weak var webView: WKWebView?
        var onAction: (PomoAmpSkinAction) -> Void
        var state: PomoAmpSkinState?
        var viz: PomoAmpVizData?
        var profile: PomoAmpVisualizerProfile?
        var skinDirectory: URL?
        private var lastStateJSON: String?
        private var lastVizJSON: String?
        private var lastProfileJSON: String?
        private var lastVizDispatchHostTime = 0.0

        init(onAction: @escaping (PomoAmpSkinAction) -> Void) {
            self.onAction = onAction
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any],
                  let type = body["type"] as? String
            else { return }

            if type == "ready" {
                PomoAmpDebugLog.write("skin bridge ready")
                sendProfile(force: true)
                sendState(force: true)
                sendViz(force: true)
                return
            }
            if type == "log" {
                let message = body["message"] as? String ?? ""
                let detail = body["detail"] ?? [:]
                PomoAmpDebugLog.write("skin js \(message) detail=\(detail)")
                return
            }
            if type == "action",
               let name = body["name"] as? String {
                guard let action = PomoAmpSkinAction(skinName: name) else {
                    PomoAmpDebugLog.write("skin bridge unknown action name=\(name) body=\(body)")
                    return
                }
                PomoAmpDebugLog.write("skin bridge action received name=\(name) mapped=\(action.rawValue)")
                onAction(action)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            sendProfile(force: true)
            sendState(force: true)
            sendViz(force: true)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard navigationAction.targetFrame?.isMainFrame != false,
                  let url = navigationAction.request.url,
                  isAllowedSkinURL(url)
            else {
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        func sendState(force: Bool = false) {
            guard let webView, let state,
                  let data = try? JSONEncoder().encode(state),
                  let json = String(data: data, encoding: .utf8)
            else { return }
            guard force || json != lastStateJSON else { return }
            lastStateJSON = json
            webView.evaluateJavaScript("window.__yampReceiveState && window.__yampReceiveState(\(json));", completionHandler: nil)
        }

        func sendProfile(force: Bool = false) {
            guard let webView, let profile,
                  let data = try? JSONEncoder().encode(profile),
                  let json = String(data: data, encoding: .utf8)
            else { return }
            guard force || json != lastProfileJSON else { return }
            lastProfileJSON = json
            webView.evaluateJavaScript("window.__yampReceiveProfile && window.__yampReceiveProfile(\(json));", completionHandler: nil)
        }

        func sendViz(force: Bool = false) {
            guard let webView, let viz else { return }
            if !force {
                let fps = max(1.0, profile?.skinFPS ?? 15.0)
                let minInterval = viz.isPlaying ? 1.0 / fps : 1.0
                guard viz.hostTime - lastVizDispatchHostTime >= minInterval else { return }
            }
            guard let data = try? JSONEncoder().encode(viz),
                  let json = String(data: data, encoding: .utf8)
            else { return }
            guard force || json != lastVizJSON else { return }
            lastVizJSON = json
            lastVizDispatchHostTime = viz.hostTime
            webView.evaluateJavaScript("window.__yampReceiveViz && window.__yampReceiveViz(\(json));", completionHandler: nil)
        }

        private func isAllowedSkinURL(_ url: URL) -> Bool {
            guard url.isFileURL,
                  let skinDirectory
            else { return false }
            let basePath = skinDirectory.standardizedFileURL.path
            let path = url.standardizedFileURL.path
            return path == basePath || path.hasPrefix(basePath + "/")
        }
    }
}
